//
//  OpenGLViewViewController03.m
//  OpenGLESDemo
//
//  Created by 张杰 on 2022/6/25.
//

#import "OpenGLViewViewController03.h"
#import "OpenGLView03.h"

@interface OpenGLViewViewController03 ()

@end

@implementation OpenGLViewViewController03

- (void)viewDidLoad {
    [super viewDidLoad];
    
    OpenGLView03 *testView = [[OpenGLView03 alloc] initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, 500)];
    
    [self.view addSubview:testView];
    
    NSLog(@"...03");
}

@end
