//
// Created by visoc on 2021/12/2.
//

#include "Utils.h"
#include <arpa/inet.h>
#include <netdb.h>

#define LOGD(...) {}

/**
 * 将AVFrame(YUV420格式)保存为JPEG格式的图片
 * @param out_file 输出文件路径
 * @param pFrame 解码完的帧
 * @param width YUV420的宽
 * @param height YUV420的高
 * @return 0 代表成功，其他失败
 */
int Frame2JPG(const char *out_file, AVFrame *pFrame, int width, int height) {
    // 分配AVFormatContext对象
    AVFormatContext *pFormatCtx = avformat_alloc_context();

    // 设置输出文件格式
    pFormatCtx->oformat = av_guess_format("mjpeg", NULL, NULL);
    // 创建并初始化一个和该url相关的AVIOContext
    if (avio_open(&pFormatCtx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0) {
        LOGD("Couldn't open output file.");
        return -1;
    }

    // 构建一个新stream
    AVStream *pAVStream = avformat_new_stream(pFormatCtx, 0);
    if (pAVStream == NULL) {
        LOGD("Frame2JPG::avformat_new_stream error.");
        return -1;
    }

    // 设置该stream的信息
    AVCodecContext *pCodecCtx = pAVStream->codec;

    pCodecCtx->codec_id = pFormatCtx->oformat->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUVJ420P;
    pCodecCtx->width = width;
    pCodecCtx->height = height;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;

    // Begin Output some information
    // av_dump_format(pFormatCtx, 0, out_file, 1);
    // End Output some information

    // 查找解码器
    AVCodec *pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        LOGD("找不到图片编码器.");
        return -1;
    }
    // 设置pCodecCtx的解码器为pCodec
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        LOGD("Could not open codec.");
        return -1;
    }

    //Write Header
    int ret = avformat_write_header(pFormatCtx, NULL);
    if (ret < 0) {
        LOGD("Frame2JPG::avformat_write_header.\n");
        return -1;
    }

    int y_size = pCodecCtx->width * pCodecCtx->height;

    //Encode
    // 给AVPacket分配足够大的空间
    AVPacket pkt;
    av_new_packet(&pkt, y_size * 3);

    int got_picture = 0;
    ret = avcodec_encode_video2(pCodecCtx, &pkt, pFrame, &got_picture);
    if (ret < 0) {
        LOGD("Encode Error.\n");
        return -1;
    }
    if (got_picture == 1) {
        //pkt.stream_index = pAVStream->index;
        ret = av_write_frame(pFormatCtx, &pkt);
    }

    av_free_packet(&pkt);

    //Write Trailer
    av_write_trailer(pFormatCtx);

    if (pAVStream) {
        avcodec_close(pAVStream->codec);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);

    return 0;
}

/**
 * 获取当前系统时间
 */
long getCurrentTime() {
    struct timeval tv{};
    gettimeofday(&tv, nullptr);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

/**
 * unsigned char -> jbyteArray
 * @param buf
 * @param len 长度
 */
jbyteArray as_byte_array(JNIEnv *env, unsigned char *buf, int len) {
    jbyteArray array = env->NewByteArray(len);
    env->SetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte *>(buf));
    return array;
}

/**
 * jbyteArray -> unsigned char
 * @param env
 * @param array
 * @return
 */
unsigned char *as_unsigned_char_array(JNIEnv *env, jbyteArray array) {
    int len = env->GetArrayLength(array);
    auto *buf = new unsigned char[len];
    env->GetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte *>(buf));
    return buf;
}

/**
 * 传入IP字符串，返回对应的uint_32_t地址
 * @param ip 如："192.168.10.110"
 */
uint32_t getAddr(const char *ip) {
    if (ip == nullptr) return 0;
    int x = inet_addr(ip);
    if (x == (int) INADDR_NONE) {
        struct hostent *hp;
        if ((hp = gethostbyname(ip)) == nullptr) {
            return 0;
        }
        x = ((struct in_addr *) hp->h_addr)->s_addr;
    }
    return x;
}

/**
 * 在数据中找下一帧的起始位置
 * @param pBuf
 * @param startIndex
 * @param totalSize
 */
int findNextFrame(unsigned char *pBuf, int startIndex, int totalSize) {
    for (int i = startIndex; i <= totalSize - 4; i++) {
        if ((pBuf[i] == 0 && pBuf[i + 1] == 0 && pBuf[i + 2] == 0 && pBuf[i + 3] == 1)
            ||
            (pBuf[i] == 0 && pBuf[i + 1] == 0 && pBuf[i + 2] == 1)) {
            return i;
        }
    }
    return -1;
}