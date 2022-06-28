//
//  YUVBufferData.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "YUVBufferData.h"

@implementation YUVBufferData

/// 根据nv12的yuv格式image创建CVPixelBufferRef
+ (CVPixelBufferRef)pixelBufferFromNV12BufferData:(unsigned char *)bufferData width:(int)width height:(int)height {
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, (__bridge CFDictionaryRef)pixelAttributes, &pixelBuffer);
    if (result != kCVReturnSuccess) {
        NSLog(@"CVPixelBufferCreate error");
        return nil;
    }
    
    if (CVPixelBufferGetPlaneCount(pixelBuffer) != 2) {
        NSLog(@"nv12数据不对, 不是2个平面, %zu", CVPixelBufferGetPlaneCount(pixelBuffer));
        return nil;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    void *addressOfPlane0 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    size_t bytesPerRow0 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t height0 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
//    size_t width0 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    
    // addressOfPlane0每次步进bytesPerRow0, 因为对齐的原因, 必须是16/32对齐, 而图片的size不一定对齐了. 而读取data就是根据实际的width
    for (size_t i = 0; i < height0; i++) {
        memcpy(addressOfPlane0 + i * bytesPerRow0, bufferData + i * width, width);
    }
    
    void *addressOfPlane1 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t bytesPerRow1 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    size_t height1 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    
    unsigned char *uvData = bufferData + height * width;
    
    for (size_t i = 0; i < height1; i++) {
        memcpy(addressOfPlane1 + i * bytesPerRow1, uvData + i * width, width);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

@end
