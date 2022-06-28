//
//  OpenGLView04.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLView04.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "ShaderTool.h"
#import "OpenGLHelper.h"
#import "TextureObjc.h"
#import "FrameBufferObjc.h"
#import "YUVBufferData.h"

static NSString *const vShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 textCoordinate;
 
 varying highp vec2 coordinate;

 void main() {
     coordinate = textCoordinate;
     gl_Position = position;
 }
 );

static NSString *const fShader = SHADER_STRING
(
 precision mediump float;
 
 varying highp vec2 coordinate;
 
 uniform sampler2D samplerNV12_Y;
 uniform sampler2D samplerNV12_UV;
 
 uniform mat3 colorConversionMatrix;
 
 void main() {
    highp vec3 yuv;
    
    yuv.x = texture2D(samplerNV12_Y, coordinate).r;
    // 如果是full range的话, 比如kCVPixelFormatType_420YpCbCr8BiPlanarFullRange需要减⚠️
//         yuv.x = texture2D(SamplerNV12_Y, coordinate).r - (16.0/255.0);
    yuv.y = texture2D(samplerNV12_UV, coordinate).r - 0.5; //因为NV12是2平面的，对于UV平面，在加载纹理时，会指定格式，让U值存在r,g,b中，V值存在a中。
    yuv.z = texture2D(samplerNV12_UV, coordinate).a - 0.5; // U值存在r,g,b中，V值存在a中。😈
    
    gl_FragColor = vec4(colorConversionMatrix*yuv, 1.0);
    
//    highp mat3 trans = mat3(1, 1 ,1,
//                      0, -0.34414, 1.772,
//                      1.402, -0.71414, 0
//                      );
//
//    gl_FragColor = vec4(trans*yuv, 1.0);
}
 );

@interface OpenGLView04 ()

@property (nonatomic) FrameBufferObjc *frameBuffer;

@property (nonatomic) CAEAGLLayer *glLayer;

@property (nonatomic) EAGLContext *glContext;

@property (nonatomic) GLuint program;

/// 用于管理buffer data
@property (nonatomic) GLuint vao;
@property (nonatomic) GLuint vbo;

@property (nonatomic) GLuint textureNV12_Y;
@property (nonatomic) GLuint textureNV12_UV;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCache;

@end

@implementation OpenGLView04

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
    // 因为使用的是GL_TRIANGLE_STRIP(扇形)模式来绘制的, 共享中间的2个点, so点的顺序别搞错了, 不然会绘制的有问题⚠️
    GLfloat bufferData[] = {
        -1.0, -1.0, 0.0, 1.0, // 左下
        1.0, -1.0, 1.0, 1.0, // 右下
        -1.0, 1.0, 0.0, 0.0, // 左上
        1.0, 1.0, 1.0, 0.0, // 右上
    };
    
    // 通过vao来管理buffer data数据状态
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bufferData), bufferData, GL_STATIC_DRAW);
    
    GLuint position = glGetAttribLocation(self.program, "position");
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), 0);
    glEnableVertexAttribArray(position);

    GLuint textCoordinate = glGetAttribLocation(self.program, "textCoordinate");
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (GLfloat *)0 + 2);
    glEnableVertexAttribArray(textCoordinate);
    
    glBindVertexArray(0);
}

- (void)display {
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    // 使用上面设置的color绘制
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(self.program);
    
    glBindVertexArray(self.vao);
    
//    const GLfloat colorConversion709[] = { // 高清
//        1.164,  1.164, 1.164,
//        0.0, -0.213, 2.112,
//        1.793, -0.533,   0.0,
//    };

    // BT.601 full range-http://www.equasys.de/colorconversion.html
    const GLfloat colorConversion601FullRange[] = { // 超清
        1.0,    1.0,    1.0,
        0.0,    -0.343, 1.765,
        1.4,    -0.711, 0.0,
    };

    // 设置Uniform要放到glUseProgram之后⚠️
    /* 参数
     count：指明要更改的元素个数。如果目标uniform变量不是一个数组，那么这个值应该设为1；如果是数组，则应该设置为>=1。如果是matrix矩阵：指明要更改的矩阵个数
     transpose：指明是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
     value：指明一个指向count个元素的指针，用来更新指定的uniform变量
     */
    glUniformMatrix3fv(glGetUniformLocation(self.program, "colorConversionMatrix"), 1, GL_FALSE, colorConversion601FullRange);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureNV12_Y);
    glUniform1i(glGetUniformLocation(self.program, "samplerNV12_Y"), 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.textureNV12_UV);
    glUniform1i(glGetUniformLocation(self.program, "samplerNV12_UV"), 1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - 纹理

- (void)setupTexture {
    NSData *data = [NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"kunkun_nv12_690x1036" ofType:@"yuv"]];

    int width = 690;
    int height = 1036;
    
//    NSData *data = [NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"nv12_512x512" ofType:@"yuv"]];
//
//    int width = 512;
//    int height = 512;
    
    if ([self.class supportsFastTextureUpload]) {
        [self createFastTextureWithData:data width:width height:height];
    } else {
        [self createTextureWithData:data width:width height:height];
    }
    
    glUniform1i(glGetUniformLocation(self.program, "samplerNV12_Y"), 0);
    glUniform1i(glGetUniformLocation(self.program, "samplerNV12_UV"), 1);
}

- (void)createFastTextureWithData:(NSData *)data width:(int)width height:(int)height {
    CVPixelBufferRef pixelBuffer = [YUVBufferData pixelBufferFromNV12BufferData:(unsigned char *)data.bytes width:width height:height];
    
    // 因为CVPixelBuffer是YUV数据格式的，所以可以分配以下两个纹理对象
    CVOpenGLESTextureRef luminanceTextureRef = NULL;
    CVOpenGLESTextureRef chrominanceTextureRef = NULL;
    CVReturn err;
    
    // Y-plane 将其中的Y通道部分的内容上传到luminanceTextureRef
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       self.coreVideoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE,
                                                       width,
                                                       height,
                                                       GL_LUMINANCE,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &luminanceTextureRef);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        CVPixelBufferRelease(pixelBuffer);
        return;
    }
    
    self.textureNV12_Y = CVOpenGLESTextureGetName(luminanceTextureRef);
    glBindTexture(CVOpenGLESTextureGetTarget(luminanceTextureRef), self.textureNV12_Y);
    
    //设置放大和缩小时，纹理的过滤选项为：线性过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    //设置纹理X,Y轴的纹理环绕选项为：边缘像素延伸
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // 重置
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // UV-plane。UV各占width * height的1/4
    // GL_LUMINANCE_ALPHA: 将U放到luminance部分，将V放到alpha部分。这关乎后面在fragmentshader中如何拿到正确的YUV数据
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       self.coreVideoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE_ALPHA,
                                                       width / 2,
                                                       height / 2,
                                                       GL_LUMINANCE_ALPHA,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &chrominanceTextureRef);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    self.textureNV12_UV = CVOpenGLESTextureGetName(chrominanceTextureRef);
    glBindTexture(CVOpenGLESTextureGetTarget(chrominanceTextureRef), self.textureNV12_UV);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
}

/*
 第1种方案: glPixelStorei(GL_UNPACK_ALIGNMENT, 1); 改为1字节对齐(默认4字节对齐), 这样的话就算width不是4字节, 读取也没问题
 第2种方案: 将data的row转换为4字节对齐
 */
- (void)createTextureWithData:(NSData *)data width:(int)width height:(int)height {
    self.textureNV12_Y = [self.class createWithTexture];
    self.textureNV12_UV = [self.class createWithTexture];

    uint8_t *imageData = (uint8_t *)data.bytes;

    // 因为OpenGL默认像素是4字节对齐⚠️
    size_t bytesPerRow = ceil(width / 4.0) * 4.0;

    // 将data的row转换为4字节对齐
    uint8_t *yPlane = calloc(1, bytesPerRow * height);
    for (int i = 0; i < height; i++) {
        memcpy(yPlane + i * bytesPerRow, imageData + i * width, width);
    }

    uint8_t *uvData = imageData + width * height;
    uint8_t *uvPlane = calloc(1, bytesPerRow * (height / 2));
    for (int i = 0; i < height / 2; i++) {
        memcpy(uvPlane + i * bytesPerRow, uvData + i * width, width);
    }

    // 假设图尺寸 150x150, 每一個 row 的大小就會是 150 * 3 = 450 , 450 不能被 4 整除的. 如果要強行把它換成可以被 4 整除, 一般的做法, 就是在每一個 row 多加 2 bytes 沒用途的資料 (這個步驟我們叫 padding ), 如此 450 就會變成 452, 452 就可以被 4 整除了. ⚠️
    // 让字节对齐从默认的4字节对齐改成1字节对齐（选择1的话，无论图片本身是怎样都是绝对不会出问题的，嘛，以效率的牺牲为代价）
    // 最好的做法: 宽可被4整除.
//    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glBindTexture(GL_TEXTURE_2D, self.textureNV12_Y);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, yPlane);

    glBindTexture(GL_TEXTURE_2D, self.textureNV12_UV);
    // 这里是GL_LUMINANCE_ALPHA⚠️
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE_ALPHA, width / 2, height / 2, 0, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, uvPlane);
    
    // 恢复默认4字节读取
//    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
}

+ (GLuint)createWithTexture {
    GLuint texture = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // 清空
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return texture;
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

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache {
    if (_textureCache == NULL) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.glContext, NULL, &_textureCache);
        if (err) {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    return _textureCache;
}

+ (BOOL)supportsFastTextureUpload {
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

@end
