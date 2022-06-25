//
//  TextureObjc.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "TextureObjc.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@implementation TextureObjc

- (void)dealloc {
    if (_texture) {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}

- (BOOL)createTextureWithImage:(UIImage *)image {
    if (!image || image.size.width <= 0 || image.size.height <= 0) {
        NSLog(@"createTextureWithImage error image error");
        return false;
    }
    
    CGImageRef cgImage = image.CGImage;
    
    CGContextRef context = CGBitmapContextCreate(nil, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage), 8, 4 * CGImageGetWidth(cgImage), CGImageGetColorSpace(cgImage) ?: CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    if (context == nil) {
        NSLog(@"CGBitmapContextCreate error");
        return false;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);

    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);

    // 纹理参数
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // 载入
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA,
                 (int)CGImageGetWidth(cgImage),
                 (int)CGImageGetHeight(cgImage),
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 CGBitmapContextGetData(context));

    CGContextRelease(context);
    
    // 还原
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return true;
}

@end
