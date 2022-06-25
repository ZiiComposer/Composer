//
//  FrameBufferObjc.h
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FrameBufferObjc : NSObject

@property (nonatomic, readonly) GLuint renderBuffer;

@property (nonatomic, readonly) GLuint frameBuffer;

- (nullable instancetype)initWithglLager:(CAEAGLLayer *)glLayer context:(EAGLContext *)context;

@end

NS_ASSUME_NONNULL_END
