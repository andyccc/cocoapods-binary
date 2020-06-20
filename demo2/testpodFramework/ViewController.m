//
//  ViewController.m
//  testpodFramework
//
//  Created by yans on 2019/10/22.
//  Copyright © 2019 hzty. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    id array = @[
    @"1",@"2",
    ];
    
    id obj = array[3];
    
    if (obj) {
        
    }
    
    NSLog(@"obj %@", obj);
    
    
}


@end
