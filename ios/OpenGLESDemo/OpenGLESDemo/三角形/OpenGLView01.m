//
//  OpenGLView01.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import "OpenGLView01.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "ShaderTool.h"
#import "OpenGLHelper.h"

static NSString *const vShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 color;
 
 // 传递给纹理着色器
 varying lowp vec4 display_color;

 void main() {
    display_color = color;
    gl_Position = position;
 }
 );

static NSString *const fShader = SHADER_STRING
(
 varying lowp vec4 display_color;
 
 void main() {
    gl_FragColor = display_color;
}
 );

@interface OpenGLView01 ()

@property (nonatomic) CAEAGLLayer *glLayer;
@property (nonatomic) EAGLContext *glContext;

@property (nonatomic) GLuint frameBuffer;
@property (nonatomic) GLuint renderBuffer;

/// 程序
@property (nonatomic) GLuint program;

/// array buffer object
@property (nonatomic) GLuint vbo;

@end

@implementation OpenGLView01

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)dealloc {
    glDeleteProgram(self.program);
    
    glDeleteFramebuffers(1, &_frameBuffer);
    glDeleteRenderbuffers(1, &_renderBuffer);
    
    if (_vbo) {
        glDeleteBuffers(1, &_vbo);
    }
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - private

- (void)setup {
    [self setupLayer];
    [self setupShader];
    [self setupFrameBuffer];
    [self setupData];
    [self display];
}

- (void)setupLayer {
    self.glLayer = (CAEAGLLayer *)self.layer;
    
    self.glLayer.opaque = true; // 不做图层混合
    self.glLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @(false),
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    self.contentScaleFactor = UIScreen.mainScreen.scale;
    
    if ([EAGLContext currentContext] != self.glContext) {
        [EAGLContext setCurrentContext:self.glContext];
    }
}

- (void)setupShader {
    self.program = glCreateProgram();
    
    GLuint vsh = [self.class creatShaderWithSource:vShader shaderType:GL_VERTEX_SHADER];
    GLuint fsh = [self.class creatShaderWithSource:fShader shaderType:GL_FRAGMENT_SHADER];
    
    glAttachShader(self.program, vsh);
    glAttachShader(self.program, fsh);
    
    glDeleteShader(vsh);
    glDeleteShader(fsh);
    
    glLinkProgram(self.program);
    
    if (![ShaderTool checkLinkStatusProgram:self.program]) {
        NSLog(@"link error");
    }
}

- (void)setupFrameBuffer {
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);
    
    [self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"frame buffer error");
    }
}

- (void)setupData {
    // 左上角
    GLfloat data[] = {
        -1.0, 1.0, 0.4, 0.6, 0.2, 1.0, // 左上
        -1.0, -1.0, 0.4, 0.6, 0.2, 1.0, // 左下
        1.0, -1.0, 0.4, 0.6, 0.2, 1.0, // 右下
    };
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW);
    
    GLuint position = glGetAttribLocation(self.program, "position");
    GLuint color = glGetAttribLocation(self.program, "color");
    
    glEnableVertexAttribArray(color);
    glEnableVertexAttribArray(position);
    
    // 用2个数据
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), 0);
    // 用4个数据
    glVertexAttribPointer(color, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLfloat *)0 + 2);
}

- (void)display {
    // 绘制的窗口大小
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    // 使用上面设置的color绘制
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(self.program);
    
    // 绘制
    glDrawArrays(GL_TRIANGLES, 0, 3);
    
    // 展示到渲染缓冲区
    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - help

+ (GLuint)creatShaderWithSource:(NSString *)source shaderType:(GLenum)shaderType {
    GLuint shader = glCreateShader(shaderType);
    const GLchar *cchar = source.UTF8String;
    // 把shader的代码添加到shader上
    glShaderSource(shader, 1, &cchar, nil);
    // 编译
    glCompileShader(shader);
    
    [self checkShaderStatus:shader];
    
    return shader;
}

/// 检查shader的状态
+ (void)checkShaderStatus:(GLuint)shader {
    // 检查着色器错误
    GLint testVal;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &testVal);
    if (testVal == GL_FALSE) {
        char message[1024];
        glGetShaderInfoLog(shader, 1024, NULL, message);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"shader create Error:%@",messageString);
        glDeleteShader(shader);
        return;
    }
}

#pragma mark - 懒加载

- (EAGLContext *)glContext {
    if (!_glContext) {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return _glContext;
}

@end
