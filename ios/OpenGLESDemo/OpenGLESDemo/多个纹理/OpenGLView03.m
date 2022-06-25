//
//  OpenGLView03.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLView03.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "ShaderTool.h"
#import "OpenGLHelper.h"
#import "TextureObjc.h"
#import "FrameBufferObjc.h"

static NSString *const vShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 textCoordinate;
 
 varying lowp vec2 varyTextCoord;

 void main() {
     varyTextCoord = textCoordinate;
     gl_Position = position;
 }
 );

static NSString *const fShader = SHADER_STRING
(
 varying lowp vec2 varyTextCoord;
 
 uniform sampler2D ourTexture1;
 uniform sampler2D ourTexture2;
 
 void main() {
    lowp vec4 colorA = texture2D(ourTexture1, varyTextCoord);
    lowp vec4 colorB = texture2D(ourTexture2, varyTextCoord);
    
    gl_FragColor = colorA * 0.8 + colorB * 0.2;
}
 );

@interface OpenGLView03 ()

@property (nonatomic) TextureObjc *texture0;
@property (nonatomic) TextureObjc *texture1;

@property (nonatomic) FrameBufferObjc *frameBuffer;

@property (nonatomic) CAEAGLLayer *glLayer;

@property (nonatomic) EAGLContext *glContext;

@property (nonatomic) GLuint program;

/// 用于管理buffer data
@property (nonatomic) GLuint vao;
@property (nonatomic) GLuint vbo;
@property (nonatomic) GLuint ebo;

@end

@implementation OpenGLView03

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)dealloc {
    // ...
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - private

- (void)setup {
    [self setupLayer];
    
    // 只是为了调用frameBuffer的get方法
    [self frameBuffer];
    
    self.program = [ShaderTool createProgramWithVShaderSource:vShader fShaderSource:fShader];
    
    [self setupBufferData];
    
    [self setupTexture];
    [self display];
}

- (void)setupLayer {
    self.glLayer = (CAEAGLLayer *)self.layer;
    
    self.opaque = true;
    self.glLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @(false),
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    self.contentScaleFactor = UIScreen.mainScreen.scale;
    
    if ([EAGLContext currentContext] != self.glContext) {
        [EAGLContext setCurrentContext:self.glContext];
    }
}

- (void)setupBufferData {
    GLfloat bufferData[] = {
        -1.0, 1.0, 0.0, 0.0, // 左上
        -1.0, -1.0, 0.0, 1.0, // 左下
        1.0, -1.0, 1.0, 1.0, // 右下
        1.0, 1.0, 1.0, 0.0, // 右上
    };
    
    GLuint indices[] = {  // Note that we start from 0!
        0, 1, 3, // First Triangle
        1, 2, 3  // Second Triangle
    };
    
    // 通过vao来管理buffer data数据状态
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bufferData), bufferData, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    GLuint position = glGetAttribLocation(self.program, "position");
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), 0);
    glEnableVertexAttribArray(position);

    GLuint textCoordinate = glGetAttribLocation(self.program, "textCoordinate");
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (GLfloat *)0 + 2);
    glEnableVertexAttribArray(textCoordinate);
    
    glBindVertexArray(0);
}

- (void)setupTexture {
    BOOL ret = [self.texture0 createTextureWithImage:[UIImage imageNamed:@"wall"]];
    if (!ret) {
        NSLog(@"创建texture0 error");
    }
    
    ret = [self.texture1 createTextureWithImage:[UIImage imageNamed:@"haha"]];
    if (!ret) {
        NSLog(@"创建texture1 error");
    }
}

- (void)display {
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    // 使用上面设置的color绘制
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(self.program);
    
    glBindVertexArray(self.vao);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.texture0.texture);
    glUniform1i(glGetUniformLocation(self.program, "ourTexture1"), 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.texture1.texture);
    glUniform1i(glGetUniformLocation(self.program, "ourTexture1"), 1);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, nil);
    
    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - 懒加载

- (EAGLContext *)glContext {
    if (!_glContext) {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return _glContext;
}

- (FrameBufferObjc *)frameBuffer {
    if (!_frameBuffer) {
        _frameBuffer = [[FrameBufferObjc alloc] initWithglLager:self.glLayer context:self.glContext];
    }
    return _frameBuffer;
}

- (TextureObjc *)texture0 {
    if (!_texture0) {
        _texture0 = [[TextureObjc alloc] init];
    }
    return _texture0;
}

- (TextureObjc *)texture1 {
    if (!_texture1) {
        _texture1 = [[TextureObjc alloc] init];
    }
    return _texture1;
}

@end
