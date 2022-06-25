//
//  OpenGLViewViewController02.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLViewViewController02.h"
#import "OpenGLView02.h"

@interface OpenGLViewViewController02 ()

@end

@implementation OpenGLViewViewController02

- (void)viewDidLoad {
    [super viewDidLoad];
    
    OpenGLView02 *testView = [[OpenGLView02 alloc] initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, 500)];
    
    [self.view addSubview:testView];
    
    NSLog(@"...OpenGLViewViewController02");
}

@end
