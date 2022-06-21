package com.viso.composer

import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Environment
import android.util.Log
import android.view.Surface
import java.io.*


/**
 * Created by visoc on 2021/11/30.
 */
class MediaCodecPlayer {
    companion object {
        const val TAG = "MediaCodecPlayer"

        fun findByFrame(bytes: ByteArray, start: Int, totalSize: Int): Int {
            val byte00: Byte = 0b00
            val byte01: Byte = 0b01
            for (i in start until totalSize - 4) {
                if ((bytes[i] == byte00 && bytes[i + 1] == byte00 && bytes[i + 2] == byte00 && bytes[i + 3] == byte01)
                    ||
                    (bytes[i] == byte00 && bytes[i + 1] == byte00 && bytes[i + 2] == byte01)
                ) {
                    return i
                }
            }
            return -1
        }

        @Throws(IOException::class)
        fun getBytes(path: String): ByteArray {
            val `is`: InputStream = DataInputStream(FileInputStream(File(path)))
            var len: Int
            val size = 1024
            val bos = ByteArrayOutputStream()
            var buf: ByteArray = ByteArray(size)
            while (`is`.read(buf, 0, size).also { len = it } != -1) bos.write(buf, 0, len)
            buf = bos.toByteArray()
            return buf
        }
    }

    private var bytes: ByteArray? = null
    private val path: String = File(Environment.getExternalStorageDirectory(), "record.h264").absolutePath
    private var codec: MediaCodec? = null
    private var startIndex: Int = 0

    private var ts = 0L
    private var frames = 0
    private var renderTs = 0L
    private var renderFrames = 0

    private var rend = true;
    fun initCodec(surface: Surface) {
        codec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        //设置回调方法必须在mediacodec创建之后，并且在configure方法之前
        codec!!.setCallback(object : MediaCodec.Callback() {
            override fun onInputBufferAvailable(codec: MediaCodec, inputBufferId: Int) {
                Log.d(TAG, "onInputBufferAvailable: $inputBufferId")
                if (inputBufferId < 0) return
                val inputBuffer = codec.getInputBuffer(inputBufferId) ?: return
                val nextFrameStart = findByFrame(bytes!!, startIndex + 3, bytes!!.size)
                //流结束了
                if (nextFrameStart < 0) {
                    codec.queueInputBuffer(inputBufferId, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);//第三个时间戳可以随意设置
                    return
                }
                val length: Int = nextFrameStart - startIndex
                Log.d(TAG, "nextFrameStart: $nextFrameStart $length")
                inputBuffer.put(bytes, startIndex, length)
                //通知dsp解码
                codec.queueInputBuffer(inputBufferId, 0, length, 0, 0)
                startIndex = nextFrameStart

                //统计帧数
                val curTs: Long = System.currentTimeMillis()
                if (curTs - ts >= 1000) {
                    Log.d(TAG, "收到数据帧数: $frames")
                    frames = 0
                    ts = curTs
                }
                frames++
            }

            override fun onOutputBufferAvailable(codec: MediaCodec, outputBufferId: Int, info: MediaCodec.BufferInfo) {
//                val outputBuffer = codec.getOutputBuffer(outputBufferId)
//                val bufferFormat = codec.getOutputFormat(outputBufferId)// option A
                // bufferFormat is equivalent to mOutputFormat
                // outputBuffer is ready to be processed or rendered.
                //…
                Log.d(TAG, "onOutputBufferAvailable: $outputBufferId")
                if (outputBufferId >= 0) {
//                    if (rend) {
                        codec.releaseOutputBuffer(outputBufferId, true)
                        //统计帧数
                        val curTs: Long = System.currentTimeMillis()
                        if (curTs - renderTs >= 1000) {
                            Log.d(TAG, "渲染帧数: $renderFrames")
                            renderFrames = 0
                            renderTs = curTs
                        }
                        renderFrames++
//                    }
                    rend = !rend
                }
            }

            override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
                Log.d(TAG, "onError: ${e.message}")
            }

            override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
                //format是变化后的MediaFormat，在h264流里边这个就是sps和pps
                Log.d(TAG, "onOutputFormatChanged: $format")
            }
        })
        val mediaFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1280, 720)
        //setup mediaFormat
//        mediaFormat.setInteger(MediaFormat.KEY_FRAME_RATE, 15)
        codec!!.configure(mediaFormat, surface, null, 0)
    }

    fun decodeFile(block: () -> Unit) {
        Thread {
            bytes = getBytes(path)
            Log.d(TAG, "play: ${bytes!!.size}")
            block.invoke()
        }.start()
    }

    fun play() {
        codec?.start()
    }

    fun releaseCodec() {
        codec?.stop()
        codec?.release()
        codec = null
        startIndex = 0
    }
}