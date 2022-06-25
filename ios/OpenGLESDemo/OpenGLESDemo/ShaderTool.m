//
//  ShaderTool.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import "ShaderTool.h"

@implementation ShaderTool

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
