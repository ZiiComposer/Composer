#include <jni.h>
#include <string>
#include<android/log.h>
#include <android/native_window_jni.h>
#include <unistd.h>//usleep
#include "Utils.h"
#include "AVpacket_queue.h"

//ffmpeg是C语音写的，所以所有头文件的引用要加 extern "C"{};
extern "C"
{
#include <libavdevice/avdevice.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libswscale/swscale.h>
#include "libavutil/imgutils.h"
#include <libswresample/swresample.h>
#include <libavutil/time.h>
}

//#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG,"lalala" ,__VA_ARGS__)
//#define LOGI(...) __android_log_print(ANDROID_LOG_DEBUG,"wawawa" ,__VA_ARGS__)

#define LOGD(...) {}
#define LOGI(...) {}

pthread_mutex_t mutex; // 申明一个互斥锁
AVPacketQueue *packets;

void initMutex() {
    packets = queue_init(60);//最大缓存60帧
    pthread_mutex_init(&mutex, nullptr); // 创建锁
}

void releaseMutex() {
    queue_free(packets);
    pthread_mutex_destroy(&mutex);   // 销毁锁
}

void resetPacketQueue() {
    pthread_mutex_lock(&mutex);
    queue_reset(packets);
    pthread_mutex_unlock(&mutex);
}

AVPacket **readPacket() {
    pthread_mutex_lock(&mutex);
    auto data = (AVPacket **) queue_pop(packets, &mutex, nullptr);
    pthread_mutex_unlock(&mutex);
    return data;
}

//long sysTs = 0;
//int frames = 0;
void writePacket(unsigned char *pData, int size, int keyFrame) {
    if (size == 0) {
        LOGD("writePacket:%d", size);
        return;
    }
//    long curTs = getCurrentTime();
//    if (curTs - sysTs >= 1000) {
//        LOGD("收到数据: %d 帧数: %d", size, frames);
//        frames = 0;
//        sysTs = curTs;
//    }
//    frames++;
    pthread_mutex_lock(&mutex);
    AVPacket *packet = av_packet_alloc();
    packet->data = pData;
    packet->size = size;
    packet->flags = keyFrame;//1.关键帧
    queue_push(packets, packet, &mutex, nullptr);
    pthread_mutex_unlock(&mutex);
}

bool saveVideo = false;//保存视频帧到本地文件
const char *videoSavePath = "";//视频存储目录
bool captureImg = false;//截屏生成图片
const char *captureImgPath = "";//图片保存目录

bool isRunning = false;//socket连接中
bool shouldDecode = false;//解码&播放中

int frameRatio = 0;//帧率控制，0表示不控制帧率
int frameCnt = 0;//当前帧数
long cyclerStartTime = 0;//这一轮的起始时间

void onSaveImgFinish(JNIEnv *env, jobject jobject1, int code) {
    jclass cls = env->GetObjectClass(jobject1);
    jmethodID method = env->GetMethodID(cls, "saveImgFinish", "(I)V");
    env->CallVoidMethod(jobject1, method, code);
}
//typedef struct _StreamEncode_ATTR_S {
//    unsigned int Identifier;//标识0xAAAAAAAA
//    unsigned char EncodeType;//编码模式
//    unsigned char FreamRate;//帧率
//    unsigned short Width;//宽度
//    unsigned short Height;//高度
//} tagStreamEncode_ATTR_S;

static void *
MediaServer_EventHandler(unsigned char *pBuf, int nSize, unsigned char *mediatype, int i1, int i2, int bKeyFrame, int i4, int i5, int i6, int i7, long nhand) {
    //pBuf大部分时候是完整的一帧，但也会出现少部分数据里混了三帧错误帧数据在前面
    if (shouldDecode) {
        //保存视频文件
        if (saveVideo) {
            FILE *file = fopen(videoSavePath, "ab+");
            if (file == nullptr) {
                LOGD("文件创建失败");
            } else {
                fwrite(pBuf, 1, nSize, file);
                fclose(file);
            }
        }

        int realSize = nSize - 10;// sizeof(tagStreamEncode_ATTR_S)在推流的机器上是10？我的手机上是12
        if (realSize <= 0) return nullptr;
        //分配个新buf，一定不能用pBuf送去入队，否则会花屏，pBuf在socket处理逻辑里会调整
        auto *buf2 = new unsigned char[realSize];
        memcpy(buf2, pBuf, realSize);
        writePacket(buf2, realSize, bKeyFrame);
    }
    return nullptr;
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_writePacket(
        JNIEnv *env, jobject /* this */, jbyteArray bytes, jint size, jboolean bKeyFrame) {
    if (shouldDecode) {
        writePacket(as_unsigned_char_array(env, bytes), size, bKeyFrame);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_init(
        JNIEnv *env, jobject /* this */) {
    initMutex();
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_connect(JNIEnv *env, jobject js, jstring ip, jint port) {
//    VideoLiveTcpClient client = VideoLiveTcpClient(1);
//    const char *ipChar = (env)->GetStringUTFChars(ip, JNI_FALSE);
//    client.OnInitListRun(MediaServer_EventHandler, port, 2);
//    client.OnSetUse(getAddr(ipChar));
    isRunning = true;
    do {
        usleep(1000 * 1000);
    } while (isRunning);
    //这里执行完后，这里创建的局部c++对象会被析构，终究是不熟悉啊，其实跟java是一样的
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_disconnect(JNIEnv *env, jobject /* this */) {
    isRunning = false;
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_startPlay(JNIEnv *env, jobject jobj, jobject surface) {
    //注册
    avcodec_register_all();
    //获取解码器
    AVCodec *pCodec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (pCodec == nullptr) {
        LOGI("H264 Codec not found.");
        return;
    }
    AVCodecContext *pCodecCtx = avcodec_alloc_context3(pCodec);
    //打开解码器
    if (avcodec_open2(pCodecCtx, pCodec, nullptr) < 0) {
        LOGI("Could not open codec.");
        return;
    }
    //获取NativeWindow，用于渲染视频
    ANativeWindow *nativeWindow = ANativeWindow_fromSurface(env, surface);
    //定义绘图缓冲区
    ANativeWindow_Buffer windowBuffer;
    LOGI("native window ready!原生绘制工具准备完成");

    //release包可以关闭log输出
//    av_log_set_callback(nullptr);
    AVFrame *pFrameOut = av_frame_alloc();
    if (pFrameOut == nullptr) {
        LOGI("Could not allocate video frame.\n");
        return;
    }
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    /* uint8_t *buffer;
     buffer== nullptr 在debug时为true，release时为false*/
    //所以必须赋默认值nullptr
    uint8_t *buffer = nullptr;
    struct SwsContext *sws_ctx = nullptr;
    AVFrame *pFrame = av_frame_alloc();
    if (pFrame == nullptr) {
        LOGI("av_frame_alloc fail.");
        return;
    }
    shouldDecode = true;
    bool firstIFrameSent = false;
    while (shouldDecode) {
//        long ts = getCurrentTime();
        //从缓存队列取数据
        AVPacket **dataArray = readPacket();
        if (dataArray == nullptr) {
            LOGI("read null array");
            continue;
        }
        //读一次数据只渲染一帧
        bool rended = false;
        for (int i = 0; i < AVPacketQueue::maxLevel; i++) {
            AVPacket *data = dataArray[i];
            if (data == nullptr) {
                LOGI("read null");
                continue;
            }
            if (data->size == 0) {
                //https://blog.csdn.net/wh8_2011/article/details/84587881
                LOGI("writePacket:avcodec_frame size = 0!");
                continue;
            }
            //is keyframe
            if (!firstIFrameSent && !(data->flags & AV_PKT_FLAG_KEY)) {
                LOGI("过滤前期无效帧");
                continue;
            }
            firstIFrameSent = true;
//            long decodeTs = getCurrentTime();
//            LOGI("读取数据耗时 :%lo", (decodeTs - ts));
            //解码AVPacket->AVFrame
            //https://juejin.cn/post/7022653742029733925
            int tempResult = avcodec_send_packet(pCodecCtx, data);
            if (tempResult < 0 && tempResult != AVERROR(EAGAIN) && tempResult != AVERROR_EOF) {
                LOGI("ERROR FRAME: avcodec_frame size = %d!        errorCode = %d", data->size, tempResult);
                continue;
            }
            do {
                //读取到一帧视频
                tempResult = avcodec_receive_frame(pCodecCtx, pFrame);
                if (tempResult == AVERROR(EAGAIN)) {
                    //需要更多数据
//                    LOGI("avcodec_frame 需要更多数据出帧 %d", data->size);
                } else if (tempResult < 0) {
                    LOGI("ERROR FRAME: avcodec_frame 出帧错误 %d", data->size);
                } else {
//                    LOGI("解码数据耗时 :%lo %d %d", (getCurrentTime() - decodeTs), pCodecCtx->width, pCodecCtx->height);
                    if (!rended) {
                        rended = true;
                        bool skipNextRender = false;//太快了，跳帧
                        //帧率控制逻辑
                        if (frameRatio > 0) {//启用帧率控制功能
                            long curTime = getCurrentTime();
                            if (curTime - cyclerStartTime >= 1000) {
                                cyclerStartTime = curTime;
                                frameCnt = 0;
                            }
                            int frameRenderTime = 1000 / frameRatio;//目标耗时
                            long aheadTime = frameRenderTime * frameCnt - (curTime - cyclerStartTime);
                            if (aheadTime > frameRenderTime) {
                                //超前一帧的话就跳帧
                                skipNextRender = true;
                            }
                        }
                        if (!skipNextRender) {
                            //此时pCodecCtx也拿到了width/height
                            if (buffer == nullptr || sws_ctx == nullptr) {
                                ANativeWindow_setBuffersGeometry(nativeWindow, pCodecCtx->width, pCodecCtx->height, WINDOW_FORMAT_RGBA_8888);
                                //计算内存大小
                                int num = av_image_get_buffer_size(AV_PIX_FMT_RGBA, pCodecCtx->width, pCodecCtx->height, 1);
                                //分配内存
                                buffer = (uint8_t *) av_malloc(num * sizeof(uint8_t));
                                //对申请的内存进行格式化
                                //align表示按多少个字节对齐
                                av_image_fill_arrays(pFrameOut->data, pFrameOut->linesize, buffer, AV_PIX_FMT_RGBA, pCodecCtx->width, pCodecCtx->height, 1);
                                sws_ctx = sws_getContext(
                                        pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                        pCodecCtx->width, pCodecCtx->height, AV_PIX_FMT_RGBA,
                                        SWS_BICUBIC, nullptr, nullptr, nullptr);
                                if (sws_ctx == nullptr) {
                                    LOGI("sws_ctx==null");
                                    break;
                                }
                            }
                            //执行转码
                            sws_scale(sws_ctx, pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameOut->data, pFrameOut->linesize);
                            //锁定窗口绘图界面
                            if (ANativeWindow_lock(nativeWindow, &windowBuffer, nullptr) < 0) {
                                LOGI("窗口锁定失败");
                            } else {
                                auto *dst = (uint8_t *) windowBuffer.bits;
                                for (int h = 0; h < pCodecCtx->height; h++) {
                                    memcpy(dst + h * windowBuffer.stride * 4, buffer + h * pFrameOut->linesize[0], pFrameOut->linesize[0]);
                                }
                            }
                            //解锁窗口
                            ANativeWindow_unlockAndPost(nativeWindow);
                            //LOGI("渲染耗时:%lo", (getCurrentTime() - renderTss));
                            frameCnt++;
                        }
                    } else {
                        LOGD("跳帧 %d", i);
                    }
                    if (captureImg) {
                        captureImg = false;
                        if (Frame2JPG(captureImgPath, pFrame, pCodecCtx->width, pCodecCtx->height) == 0) {
                            onSaveImgFinish(env, jobj, 0);
                        } else {
                            onSaveImgFinish(env, jobj, -1);
                        }
                    }
                }
            } while (tempResult == 0);
            av_packet_unref(data);
        }
        for (int i = 0; i < AVPacketQueue::maxLevel; i++) {
            free(dataArray[i]);
        }
        free(dataArray);
//        LOGI("数据包耗时:%lo", (getCurrentTime() - ts));
    }
    //回收资源
    //释放图像帧
    av_frame_free(&pFrame);
    av_frame_free(&pFrameOut);
    if (buffer != nullptr) {
        av_free(buffer);
    }
    //关闭转码上下文
    if (sws_ctx != nullptr) {
        sws_freeContext(sws_ctx);
    }
    //关闭解码器
    avcodec_close(pCodecCtx);
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_stopPlay(JNIEnv *env, jobject /* this */) {
    shouldDecode = false;
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_postResume(JNIEnv *env, jobject /* this */) {
    resetPacketQueue();
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_captureImg(JNIEnv *env, jobject /* this */, jstring path) {
    captureImg = true;
    captureImgPath = env->GetStringUTFChars(path, JNI_FALSE);
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_saveVideo(JNIEnv *env, jobject /* this */, jstring path) {
    saveVideo = true;
    videoSavePath = env->GetStringUTFChars(path, JNI_FALSE);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_viso_composer_MainActivity_stopSaveVideo(JNIEnv *env, jobject /* this */) {
    saveVideo = false;
    return env->NewStringUTF(videoSavePath);
}

extern "C" JNIEXPORT void JNICALL
Java_com_viso_composer_MainActivity_limitFps(JNIEnv *env, jobject /* this */, jint fps) {
    frameRatio = fps;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_viso_composer_MainActivity_h246ToMp4(JNIEnv *env, jobject, jstring h264Path, jstring mp4Path) {
    AVOutputFormat *ofmt = NULL;
    //Input AVFormatContext and Output AVFormatContext
    AVFormatContext *ifmt_ctx_v = NULL, *ifmt_ctx_a = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    int ret, i;
    int videoindex_v = 0, videoindex_out = 0;
    int frame_index = 0;
    int64_t cur_pts_v = 0, cur_pts_a = 0;
    const char *in_filename_v = env->GetStringUTFChars(h264Path, JNI_FALSE);
    const char *out_filename = env->GetStringUTFChars(mp4Path, JNI_FALSE);//Output file URL
    av_register_all();
    //Input
    if ((ret = avformat_open_input(&ifmt_ctx_v, in_filename_v, 0, 0)) < 0) {
        LOGD("Could not open input file.");
        avformat_close_input(&ifmt_ctx_v);
        /* close output */
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
            avio_close(ofmt_ctx->pb);
        avformat_free_context(ofmt_ctx);
        if (ret < 0 && ret != AVERROR_EOF) {
            LOGD("Error occurred.\n");
            return -1;
        }

    }
    if ((ret = avformat_find_stream_info(ifmt_ctx_v, 0)) < 0) {
        LOGD("Failed to retrieve input stream information");
        avformat_close_input(&ifmt_ctx_v);
        /* close output */
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
            avio_close(ofmt_ctx->pb);
        avformat_free_context(ofmt_ctx);
        if (ret < 0 && ret != AVERROR_EOF) {
            LOGD("Error occurred.\n");
            return -1;
        }
    }

    LOGD("===========Input Information==========\n");
    av_dump_format(ifmt_ctx_v, 0, in_filename_v, 0);
    //av_dump_format(ifmt_ctx_a, 0, in_filename_a, 0);
    LOGD("======================================\n");
    //Output
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        LOGD("Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        avformat_close_input(&ifmt_ctx_v);
        /* close output */
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
            avio_close(ofmt_ctx->pb);
        avformat_free_context(ofmt_ctx);
        if (ret < 0 && ret != AVERROR_EOF) {
            LOGD("Error occurred.\n");
            return -1;
        }
    }
    ofmt = ofmt_ctx->oformat;
    LOGD("ifmt_ctx_v->nb_streams=%d\n", ifmt_ctx_v->nb_streams);
    for (i = 0; i < ifmt_ctx_v->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        //if(ifmt_ctx_v->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO)
        {
            AVStream *in_stream = ifmt_ctx_v->streams[i];
            AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
            videoindex_v = i;
            if (!out_stream) {
                LOGD("Failed allocating output stream\n");
                ret = AVERROR_UNKNOWN;
                avformat_close_input(&ifmt_ctx_v);
                /* close output */
                if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
                    avio_close(ofmt_ctx->pb);
                avformat_free_context(ofmt_ctx);
                if (ret < 0 && ret != AVERROR_EOF) {
                    LOGD("Error occurred.\n");
                    return -1;
                }
            }
            videoindex_out = out_stream->index;
            //Copy the settings of AVCodecContext
            if (avcodec_copy_context(out_stream->codec, in_stream->codec) < 0) {
                LOGD("Failed to copy context from input to output stream codec context\n");
                avformat_close_input(&ifmt_ctx_v);
                /* close output */
                if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
                    avio_close(ofmt_ctx->pb);
                avformat_free_context(ofmt_ctx);
                if (ret < 0 && ret != AVERROR_EOF) {
                    LOGD("Error occurred.\n");
                    return -1;
                }
            }
            out_stream->codec->codec_tag = 0;
            if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
                out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
            //break;
        }
    }

    LOGD("==========Output Information==========\n");
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    LOGD("======================================\n");
    //Open output file
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE) < 0) {
            LOGD("Could not open output file '%s'", out_filename);
            avformat_close_input(&ifmt_ctx_v);
            /* close output */
            if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
                avio_close(ofmt_ctx->pb);
            avformat_free_context(ofmt_ctx);
            if (ret < 0 && ret != AVERROR_EOF) {
                LOGD("Error occurred.\n");
                return -1;
            }
        }
    }
    //Write file header
    if (avformat_write_header(ofmt_ctx, NULL) < 0) {
        LOGD("Error occurred when opening output file\n");
        avformat_close_input(&ifmt_ctx_v);
        /* close output */
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
            avio_close(ofmt_ctx->pb);
        avformat_free_context(ofmt_ctx);
        if (ret < 0 && ret != AVERROR_EOF) {
            LOGD("Error occurred.\n");
            return -1;
        }
    }
    //FIX
    AVBitStreamFilterContext *h264bsfc = av_bitstream_filter_init("h264_mp4toannexb");

    while (1) {
        AVFormatContext *ifmt_ctx;
        int stream_index = 0;
        AVStream *in_stream, *out_stream;
        //Get an AVPacket
        //if(av_compare_ts(cur_pts_v,ifmt_ctx_v->streams[videoindex_v]->time_base,cur_pts_a,ifmt_ctx_a->streams[audioindex_a]->time_base) <= 0)
        {
            ifmt_ctx = ifmt_ctx_v;
            stream_index = videoindex_out;
            if (av_read_frame(ifmt_ctx, &pkt) >= 0) {
                do {
                    in_stream = ifmt_ctx->streams[pkt.stream_index];
                    out_stream = ofmt_ctx->streams[stream_index];
                    LOGD("stream_index==%d,pkt.stream_index==%d,videoindex_v=%d\n", stream_index, pkt.stream_index, videoindex_v);
                    if (pkt.stream_index == videoindex_v) {
                        //FIX：No PTS (Example: Raw H.264)
                        //Simple Write PTS
                        if (pkt.pts == AV_NOPTS_VALUE) {
                            LOGD("frame_index==%d\n", frame_index);
                            //Write PTS
                            AVRational time_base1 = in_stream->time_base;
                            //Duration between 2 frames (us)
                            int64_t calc_duration = (double) AV_TIME_BASE / av_q2d(in_stream->r_frame_rate);
                            //Parameters
                            pkt.pts = (double) (frame_index * calc_duration) / (double) (av_q2d(time_base1) * AV_TIME_BASE);
                            pkt.dts = pkt.pts;
                            pkt.duration = (double) calc_duration / (double) (av_q2d(time_base1) * AV_TIME_BASE);
                            frame_index++;
                        }
                        cur_pts_v = pkt.pts;
                        break;
                    }
                } while (av_read_frame(ifmt_ctx, &pkt) >= 0);
            } else {
                break;
            }
        }

        av_bitstream_filter_filter(h264bsfc, in_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);

        //Convert PTS/DTS
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF));
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF));
        pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        pkt.stream_index = stream_index;
        LOGD("Write 1 Packet. size:%5d\tpts:%lld\n", pkt.size, pkt.pts);
        //Write
        if (av_interleaved_write_frame(ofmt_ctx, &pkt) < 0) {
            LOGD("Error muxing packet\n");
            break;
        }
        av_free_packet(&pkt);
    }
    //Write file trailer
    av_write_trailer(ofmt_ctx);

    av_bitstream_filter_close(h264bsfc);
    avformat_close_input(&ifmt_ctx_v);
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        LOGD("Error occurred.\n");
        return -1;
    }
    return 0;

}