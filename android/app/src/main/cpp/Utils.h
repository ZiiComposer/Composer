//
// Created by visoc on 2021/12/2.
//

#include <jni.h>

//ffmpeg是C语音写的，所以所有头文件的引用要加 extern "C"{};
extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}

#ifndef COMPOSER_UTILS_H
#define COMPOSER_UTILS_H

int Frame2JPG(const char *out_file, AVFrame *pFrame, int width, int height);

long getCurrentTime();

jbyteArray as_byte_array(JNIEnv *env, unsigned char *buf, int len);

unsigned char *as_unsigned_char_array(JNIEnv *env, jbyteArray array);

uint32_t getAddr(const char *ip);

int findNextFrame(unsigned char *pBuf, int startIndex, int totalSize);

#endif //COMPOSER_UTILS_H
