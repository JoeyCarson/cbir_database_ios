//
//  CBIRQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRQuery.h"
#import "CBIRQueryDelegate.h"
#import "CBIRDatabase.h"


@implementation CBIRQuery

@synthesize delegate = _delegate;
@synthesize running = _running;
@synthesize isCanceled = _isCanceled;
@synthesize state = _state;

-(instancetype)init
{
    self = [self initWithDelegate:nil];
    return self;
}

-(instancetype)initWithDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [super init];
    if ( self ) {
        _delegate = delegate;
        _running = NO;
        _isCanceled = NO;
        _state = QUERY_INIT;
    }
    
    return self;
}

-(void) cancel
{
    _isCanceled = YES;
}

-(void) evaluate
{
    _running = YES;
    // Tell the delegate.
    [self updateState:QUERY_START];
 
    NSLog(@"evaluating the query");
    [self run];
    
    if ( self.isCanceled ) {
        [self updateState:QUERY_CANCEL];
    } else {
        [self updateState:QUERY_COMPLETE];
    }
    _running = NO;
}

-(void)updateState:(CBIR_QUERY_STATE)state
{
    if ( _state != state ) {
        _state = state;
        if ( [self.delegate respondsToSelector:@selector(stateUpdated:)] ) {
            [self.delegate stateUpdated:state];
        }
    }
}

-(void)run
{
    NSLog(@"CBIRQuery derived class must override.");
    [self doesNotRecognizeSelector:_cmd];
}

@end
