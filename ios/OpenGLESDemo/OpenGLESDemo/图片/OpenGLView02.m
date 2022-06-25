//
//  OpenGLView02.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLView02.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "ShaderTool.h"
#import "OpenGLHelper.h"

static NSString *const vShader = SHADER_STRING
(
 // 1.顶点
 attribute vec4 position;
 // 2.纹理坐标外部传入
 attribute vec2 textCoordinate;
 // 3.纹理坐标, 传递给片元着色器
 varying lowp vec2 varyTextCoord;

 void main() {
     varyTextCoord = textCoordinate;
     gl_Position = position;
 }
 );

static NSString *const fShader = SHADER_STRING
(
 varying lowp vec2 varyTextCoord;
 // 纹理采样器(获取对应的纹理ID)
 uniform sampler2D colorMap;

 void main() {
     // 纹理颜色添加对应像素点上
     // 读取纹素 vec4 texture2D(纹理, 纹理坐标); rgba
     gl_FragColor = texture2D(colorMap, varyTextCoord);
 }
 );

@interface OpenGLView02 ()

@property (nonatomic) CAEAGLLayer *glLayer;

@property (nonatomic) EAGLContext *glContext;

@property (nonatomic) GLuint frameBuffer;
@property (nonatomic) GLuint renderBuffer;

@property (nonatomic) GLuint program;

@property (nonatomic) GLuint vbo;

// 纹理
@property (nonatomic) GLuint texture;

@end

@implementation OpenGLView02

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
    
    self.program = [ShaderTool createProgramWithVShaderSource:vShader fShaderSource:fShader];
    if (self.program == -1) {
        NSLog(@"creat program error");
        return;
    }
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);

    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);

    [self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"frame buffer error");
    }
    
    [self setupBuffer];
    [self setupTexture];
    [self display];
}

- (void)setupFramebuffer {
    glDeleteRenderbuffers(1, &_renderBuffer);
    self.renderBuffer = 0;
    glDeleteFramebuffers(1, &_frameBuffer);
    self.frameBuffer = 0;
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);
    
    [self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"generator frame buffer error");
    }
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

- (void)setupBuffer {
    // 由于纹理坐标原点在左下, 而iOS原点坐标左上 (下三角形)
    GLfloat bufferData[] = {
        -1.0, 1.0, 0.0, 0.0, // 左上
        -1.0, -1.0, 0.0, 1.0, // 左下
        1.0, -1.0, 1.0, 1.0, // 右下
    };
    
//    GLfloat bufferData[] = {
//        -1.0f, -1.0f,     0.0f, 1.0f,
//        1.0f , -1.0f,     1.0f, 1.0f,
//        -1.0f,  1.0f,     0.0f, 0.0f,
//        1.0f ,  1.0f,     1.0f, 0.0f
//    };

    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bufferData), bufferData, GL_STATIC_DRAW);

    GLuint position = glGetAttribLocation(self.program, "position");
    GLuint textCoordinate = glGetAttribLocation(self.program, "textCoordinate");

    glEnableVertexAttribArray(position);
    glEnableVertexAttribArray(textCoordinate);
    
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), 0);

    // 这个(GLfloat *)0类型不要写错了, 不是GLvoid⚠️, 否则显示错误
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (GLfloat *)0 + 2);
}

- (void)setupTexture {
    UIImage *image = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"kunkun" ofType:@"jpg"]];
//    UIImage *image = [UIImage imageNamed:@"kunkun"];
    CGImageRef cgImage = image.CGImage;

    CGContextRef context = CGBitmapContextCreate(nil, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage), 8, 4 * CGImageGetWidth(cgImage), CGImageGetColorSpace(cgImage) ?: CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    if (context == nil) {
        NSLog(@"CGBitmapContextCreate error");
        return;
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
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)CGImageGetWidth(cgImage), (int)CGImageGetHeight(cgImage), 0, GL_RGBA, GL_UNSIGNED_BYTE, CGBitmapContextGetData(context));

    CGContextRelease(context);
    
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)display {
    // 绘制的窗口大小
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    // 使用上面设置的color绘制
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(self.program);
    
    // 这个要放在glUseProgram之后
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.texture);
    // 纹理采样器, 这个0对于GL_TEXTURE0的0
    GLuint ourTexture = glGetUniformLocation(self.program, "colorMap");
    glUniform1i(ourTexture, 0);
    
    // 绘制
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    
    // 展示到渲染缓冲区
    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - 懒加载

- (EAGLContext *)glContext {
    if (!_glContext) {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return _glContext;
}

@end
