//
//  YUVBufferData.h
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YUVBufferData : NSObject

/// 根据nv12的yuv格式image创建CVPixelBufferRef
+ (CVPixelBufferRef)pixelBufferFromNV12BufferData:(unsigned char *)bufferData width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
