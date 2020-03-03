//
//  AppDelegate.m
//  testpodFramework
//
//  Created by yans on 2019/10/22.
//  Copyright © 2019 hzty. All rights reserved.
//

#import "AppDelegate.h"
//#import "FTPopOverMenu.h"

#if __has_include("skegn.h")
    #import "skegn.h"
#endif

#if __has_include("STTestEngineService.h")
    #import "STTestEngineService.h"
#endif

#if __has_include(<TestEngineService/skegn.h>)
    #import <TestEngineService/skegn.h>
#endif

#if __has_include(<TestEngineService/STTestEngineService.h>)
    #import <TestEngineService/STTestEngineService.h>
#endif

#if __has_include(<MPNotificationView/OBGradientView.h>)
    #import <MPNotificationView/OBGradientView.h>
#endif

//#import <TestEngineService/STKouyuEngine.h>


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    
//    FTPopOverMenuConfiguration *config = [FTPopOverMenuConfiguration defaultConfiguration];
//    config.coverBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2];
//    config.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
//    config.separatorColor = [UIColor redColor];
//    config.backgroundColor = [UIColor redColor];
//    config.menuCornerRadius = 10;
//    config.textAlignment = NSTextAlignmentCenter;
//    config.borderWidth = 0;
//    config.menuWidth = 95;
//    config.menuRowHeight = 33;
//    config.allowRoundedArrow = YES;

#if __has_include(<MPNotificationView/OBGradientView.h>)

    OBGradientView *v = [[OBGradientView alloc] init];
    v.locations = nil;
    
#endif
    
    [NSString stringWithFormat:@""];
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
