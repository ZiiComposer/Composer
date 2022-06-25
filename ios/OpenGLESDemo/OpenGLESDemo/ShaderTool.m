//
//  ShaderTool.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import "ShaderTool.h"

@implementation ShaderTool

+ (GLuint)createProgramWithVShaderSource:(NSString *)vShaderSource fShaderSource:(NSString *)fShaderSource {
    BOOL shaderStatus = false;
    GLuint vShader = [self createShaderWithSource:vShaderSource type:GL_VERTEX_SHADER success:&shaderStatus];
    if (!shaderStatus) {
        NSLog(@"create vertex shader error");
        return -1;
    }
    
    shaderStatus = false;
    GLuint fShader = [self createShaderWithSource:fShaderSource type:GL_FRAGMENT_SHADER success:&shaderStatus];
    if (!shaderStatus) {
        NSLog(@"create fragment shader error");
        return -1;
    }
    
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader);
    glAttachShader(program, fShader);
    
    glDeleteShader(vShader);
    glDeleteShader(fShader);
    
    glLinkProgram(program);
    
    if (![self checkLinkStatusProgram:program]) {
        glDeleteProgram(program);
        return -1;
    }
    
    return program;
}

/// 创建着色器
+ (GLuint)createShaderWithSource:(NSString *)source type:(GLenum)type success:(BOOL *)success {
    GLuint shader = glCreateShader(type);
    const GLchar *string = source.UTF8String;
    glShaderSource(shader, 1, &string, nil);
    glCompileShader(shader);
    
    *success = [self checkShaderStatus:shader];
    
    return *success ? shader : -1;
}

/// 检查shader的状态
+ (BOOL)checkShaderStatus:(GLuint)shader {
    // 检查着色器错误
    GLint testVal;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &testVal);
    if (testVal == GL_FALSE) {
        char message[1024];
        glGetShaderInfoLog(shader, 1024, NULL, message);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"shader create Error:%@",messageString);
        glDeleteShader(shader);
        return false;
    }
    return true;
}

/// 检查program的链接状态
+ (BOOL)checkLinkStatusProgram:(GLuint)program {
    GLint linkStatus;
    //获取链接状态
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar message[512];
        glGetProgramInfoLog(program, sizeof(message), 0, &message[0]);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"Program Link Error:%@",messageString);
        return false;
    }
    return true;
}

@end
