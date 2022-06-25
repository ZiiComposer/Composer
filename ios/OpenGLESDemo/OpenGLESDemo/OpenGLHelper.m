//
//  OpenGLHelper.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import "OpenGLHelper.h"

@implementation OpenGLHelper

GLenum glCheckError_(const char *file, int line) {
    GLenum errorCode;
    while ((errorCode = glGetError()) != GL_NO_ERROR)
    {
        NSString *errorStr = @"";
        switch (errorCode)
        {
            case GL_INVALID_ENUM:                  errorStr = @"INVALID_ENUM"; break;
            case GL_INVALID_VALUE:                 errorStr = @"INVALID_VALUE"; break;
            case GL_INVALID_OPERATION:             errorStr = @"INVALID_OPERATION"; break;
//            case GL_STACK_OVERFLOW:                errorStr = @"STACK_OVERFLOW"; break;
//            case GL_STACK_UNDERFLOW:               errorStr = @"STACK_UNDERFLOW"; break;
            case GL_OUT_OF_MEMORY:                 errorStr = @"OUT_OF_MEMORY"; break;
            case GL_INVALID_FRAMEBUFFER_OPERATION: errorStr = @"INVALID_FRAMEBUFFER_OPERATION"; break;
        }
        NSLog(@"%@ | %s[%d]", errorStr, file, line);
    }
    return errorCode;
}

@end
