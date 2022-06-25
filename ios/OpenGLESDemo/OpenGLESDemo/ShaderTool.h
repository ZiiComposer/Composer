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

+ (GLuint)createProgramWithVShaderSource:(NSString *)vShaderSource fShaderSource:(NSString *)fShaderSource;

/// 创建着色器
+ (GLuint)createShaderWithSource:(NSString *)source type:(GLenum)type success:(BOOL *)success;

/// 检查shader的状态
+ (BOOL)checkShaderStatus:(GLuint)shader;

/// 检查program的链接状态
+ (BOOL)checkLinkStatusProgram:(GLuint)program;

@end

NS_ASSUME_NONNULL_END
