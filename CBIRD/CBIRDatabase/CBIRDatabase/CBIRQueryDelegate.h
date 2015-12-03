//
//  CBIRQueryDelegate.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CBIR_QUERY_STATE)
{
    QUERY_UNKNOWN,
    QUERY_INIT,
    QUERY_START,
    QUERY_COMPLETE,
    QUERY_CANCEL,
    QUERY_ERROR
};


@protocol CBIRQueryDelegate <NSObject>

@optional
-(void)stateUpdated:(CBIR_QUERY_STATE)state;

@end
