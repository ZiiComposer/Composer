//
//  FrameBufferObjc.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "FrameBufferObjc.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface FrameBufferObjc ()

@property (nonatomic, readwrite) GLuint renderBuffer;

@property (nonatomic, readwrite) GLuint frameBuffer;

@end

@implementation FrameBufferObjc

- (nullable instancetype)initWithglLager:(CAEAGLLayer *)glLayer context:(EAGLContext *)context {
    GLuint renderBuffer;
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    
    GLuint frameBuffer;
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
    
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:glLayer];
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"generator frame buffer error");
        return nil;
    }
    
    if (self = [super init]) {
        self.renderBuffer = renderBuffer;
        self.frameBuffer = frameBuffer;
    }
    return self;
}

- (void)dealloc {
    if (self.renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        self.renderBuffer = 0;
    }
    if (self.frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        self.frameBuffer = 0;
    }
}

@end
