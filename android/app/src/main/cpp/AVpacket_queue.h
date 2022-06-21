//
// Created by heweizong on 2019/1/11.
//

#ifndef FFMPEG_SO_AVPACKET_QUEUE_H
#define FFMPEG_SO_AVPACKET_QUEUE_H

#include <pthread.h>

extern "C"
{
#include <libavcodec/avcodec.h>
}

typedef struct AVPacketQueue {
    //队列大小
    int size;
    //指针数组
    AVPacket **packets;
    //下一个写入的packet
    int next_to_write;
    //下一个读取的packet
    int next_to_read;
    //当前是否已全部读取
    bool no_more;
    const static int maxLevel = 6;
} AVPacketQueue;

typedef struct AVPacketArray {
    //队列大小
    int size;
    //指针数组
    AVPacket **packets;
} AVPacketArray;

AVPacketQueue *queue_init(int size);

void queue_free(AVPacketQueue *queue);

void queue_push(AVPacketQueue *queue, AVPacket *packet, pthread_mutex_t *mutex, pthread_cond_t *cond);

AVPacket **queue_pop(AVPacketQueue *queue, pthread_mutex_t *mutex, pthread_cond_t *cond);

void queue_reset(AVPacketQueue *queue);

#endif //FFMPEG_SO_AVPACKET_QUEUE_H
