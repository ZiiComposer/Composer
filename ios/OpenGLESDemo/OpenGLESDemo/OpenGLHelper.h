//
//  OpenGLHelper.h
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenGLHelper : NSObject

#define glCheckError() glCheckError_(__FILE__, __LINE__)

GLenum glCheckError_(const char *file, int line);

@end

NS_ASSUME_NONNULL_END
