//
//  CBIRQuery.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBIRQueryDelegate.h"

@interface CBIRQuery : NSObject

@property (nonatomic, readonly, weak) id<CBIRQueryDelegate> delegate;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) BOOL isCanceled;
@property (nonatomic, readonly) CBIR_QUERY_STATE state;

-(instancetype)initWithDelegate:(id<CBIRQueryDelegate>)delegate NS_DESIGNATED_INITIALIZER;

-(void) evaluate;
-(void) cancel;

@end
