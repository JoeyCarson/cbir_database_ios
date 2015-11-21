//
//  main.m
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        setenv("CG_CONTEXT_SHOW_BACKTRACE", "", 1);
        int returnCode = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        return returnCode;
    }
}
