//
//  TextureObjc.h
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TextureObjc : NSObject

@property (nonatomic) GLuint texture;

/// 创建纹理
- (BOOL)createTextureWithImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
