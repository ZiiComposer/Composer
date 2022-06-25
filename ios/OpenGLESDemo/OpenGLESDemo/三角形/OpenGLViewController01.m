//
//  OpenGLViewController01.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/24.
//

#import "OpenGLViewController01.h"
#import "OpenGLView01.h"

@interface OpenGLViewController01 ()

@property (nonatomic) OpenGLView01 *testView;

@end

@implementation OpenGLViewController01

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.testView = [[OpenGLView01 alloc] initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, 500)];
    
    [self.view addSubview:self.testView];
    
    NSLog(@"...");
}

@end
