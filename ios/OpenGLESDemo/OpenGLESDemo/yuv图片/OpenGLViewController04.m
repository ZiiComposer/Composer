//
//  OpenGLViewController04.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLViewController04.h"
#import "OpenGLView04.h"

@interface OpenGLViewController04 ()

@end

@implementation OpenGLViewController04

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // png/jpg -> yuv 命令行: ffmpeg -i 大象.png -s 1906x964 -pix_fmt yuv420p 大象.yuv
    OpenGLView04 *testView = [[OpenGLView04 alloc] initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, 500)];
    
    [self.view addSubview:testView];
    
    NSLog(@"...04");
}

@end
