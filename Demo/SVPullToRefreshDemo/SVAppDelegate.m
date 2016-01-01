//
//  SVAppDelegate.m
//  SVPullToRefreshDemo
//
//  Created by Sam Vermette on 23.04.12.
//  Copyright (c) 2012 samvermette.com. All rights reserved.
//

#import "SVAppDelegate.h"
#import "SVBaseViewController.h"
#import "SVViewControllerBelowIOS7.h"
#import "SVViewControllerAboveIOS7.h"
#import "SVViewController.h"

@implementation SVAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    SVViewControllerBelowIOS7 *vc1 = [[SVViewControllerBelowIOS7 alloc] init];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:vc1];
    nav1.navigationBar.barTintColor = [UIColor colorWithRed:73.0/255.0 green:172.0/255.0 blue:198.0/255.0 alpha:1.0];
    nav1.title = @"vc1";
    
    SVViewControllerAboveIOS7 *vc2 = [[SVViewControllerAboveIOS7 alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:vc2];
    nav2.navigationBar.barTintColor = [UIColor colorWithRed:73.0/255.0 green:172.0/255.0 blue:198.0/255.0 alpha:1.0];
    nav2.title = @"vc2";
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[nav1, nav2];
    
    self.window.rootViewController = tabBarController;
    
    [self.window makeKeyAndVisible];
    return YES;
}

@end
