//
// Created by heweizong on 2019/1/11.
// 帧缓存队列
//

#include "AVpacket_queue.h"
#include <stdlib.h>

#include<android/log.h>

//#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG,"AVPacketQueue" ,__VA_ARGS__)
#define LOGD(...) {}

AVPacketQueue *queue_init(int size) {
    auto *queue = static_cast<AVPacketQueue *>(malloc(sizeof(AVPacketQueue)));
    queue->size = size;
    queue->next_to_read = 0;
    queue->next_to_write = 0;
    queue->no_more = true;
    queue->packets = static_cast<AVPacket **>(malloc(sizeof(AVPacket *) * size));
    for (int i = 0; i < size; i++) {
        queue->packets[i] = static_cast<AVPacket *>(malloc(sizeof(AVPacket)));
    }
    return queue;
}

void queue_free(AVPacketQueue *queue) {
    for (int i = 0; i < queue->size; i++) {
        free(queue->packets[i]);
    }
    free(queue->packets);
    free(queue);
}

int queue_next(AVPacketQueue *queue, int current) {
    return (current + 1) % queue->size;
}

void queue_push(AVPacketQueue *queue, AVPacket *packet, pthread_mutex_t *mutex, pthread_cond_t *cond) {
    int current = queue->next_to_write;
    if (current == queue->next_to_read && !queue->no_more) {
        LOGD("写入超一圈了 %d %d", current, queue->next_to_read);
        //策略一:主动丢帧(丢帧时必须整个GOP一起丢)
        //写超前一圈了，说明积攒了太多数据
        //所以直接让读往前移半圈
        int next_to_read = queue->next_to_read;
        queue->next_to_read = (next_to_read + queue->size / 2) % queue->size;
        //前移后再往前找下个i帧，或数据到头了
        for (;;) {
            next_to_read = queue->next_to_read;
            if (next_to_read == current) {
                LOGD("跳花屏");
                //会引起花屏
                break;
            }
            if (queue->packets[next_to_read]->flags & AV_PKT_FLAG_KEY) {
                LOGD("跳GOP");
                //会跳进度，但不会花屏
                break;
            }
            queue->next_to_read = queue_next(queue, next_to_read);
        }
    }
    queue->next_to_write = queue_next(queue, current);
    queue->packets[current] = packet;
    queue->no_more = false;
}

AVPacket **queue_pop(AVPacketQueue *queue, pthread_mutex_t *mutex, pthread_cond_t *cond) {
    auto results = static_cast<AVPacket **>(malloc(sizeof(AVPacket *) * AVPacketQueue::maxLevel));
    int current = queue->next_to_read;
    //读已经赶上写了
    if (current == queue->next_to_write) {
        //已经全部读完
        queue->no_more = true;
        return nullptr;
    }
    int gap;
    if (current > queue->next_to_write) {
        gap = queue->next_to_write + queue->size - current;
    } else {
        gap = queue->next_to_write - current;
    }
    results[0] = queue->packets[current];
    queue->next_to_read = queue_next(queue, current);
    //策略二:多级追帧(部分帧只解码不渲染)(非关键帧不解码会导致花屏，所以都得送去解码)
    //设定6级帧策略，每隔5帧加一级,1->5 2->10 3->15 ... 5->25
    //队列累积数据达到5帧的时，两帧出一幅画面，达到10帧时，3帧出一幅画面，以此类推
    for (int i = 1; i < AVPacketQueue::maxLevel; i++) {
        if (gap >= 5 * i) {
            current = queue->next_to_read;
            results[i] = queue->packets[current];
            queue->next_to_read = queue_next(queue, current);
        } else {
            results[i] = nullptr;
        }
    }
    //检查下次是否还有可读数据
    if (queue->next_to_read == queue->next_to_write) {
        queue->no_more = true;
    }
    return results;
}

void queue_reset(AVPacketQueue *queue) {
    LOGD("重置");
    queue->next_to_read = 0;
    queue->next_to_write = 0;
    queue->no_more = true;
}