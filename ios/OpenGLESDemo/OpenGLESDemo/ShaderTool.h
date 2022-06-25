//
//  ShaderTool.h
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

@interface ShaderTool : NSObject

/// 检查program的链接状态
+ (BOOL)checkLinkStatusProgram:(GLuint)program;

@end

NS_ASSUME_NONNULL_END
