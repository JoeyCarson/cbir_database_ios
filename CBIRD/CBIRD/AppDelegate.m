//
//  AppDelegate.m
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "AppDelegate.h"
#import "PhotoIndexer.h"
#import "QueryViewController.h"
#import "SecondViewController.h"

#import <CBIRDatabase/CBIRDatabase.h>

@interface AppDelegate ()

@end

@implementation AppDelegate
{
    PhotoIndexer * m_indexer;
    UITabBarController * m_rootTabVC;
    QueryViewController * queryVC;
    SecondViewController * historyVC;
}

-(instancetype)init
{
    self = [super init];
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Create the main UI.
    m_rootTabVC = [[UITabBarController alloc] init];
    queryVC = [[QueryViewController alloc] init];
    queryVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Query" image:nil tag:0];
    queryVC.delegate = self;
    
    //historyVC = [[SecondViewController alloc] initWithNibName:@"SecondViewController.nib" bundle:nil];
    //historyVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"History" image:nil tag:0];
    
    m_rootTabVC.viewControllers = @[queryVC];
    self.window = [[UIWindow alloc] init];
    [self.window setRootViewController:m_rootTabVC];
    [self.window makeKeyAndVisible];
    
    m_indexer = [[PhotoIndexer alloc] initWithDelegate:queryVC];
    [m_indexer fetchAndIndexAssetsWithOptions:nil];
    
    return YES;
}

- (void)enableIndexing:(BOOL)enabled;
{
    if ( enabled ) {
        [m_indexer resume];
    } else {
        [m_indexer pause];
    }
}



- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [m_indexer pause];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [m_indexer resume];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [CBIRDatabaseEngine shutdown];
}

@end
