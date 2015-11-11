//
//  CBIRQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRQuery.h"
#import "CBIRQueryDelegate.h"

@implementation CBIRQuery

@synthesize delegate = _delegate;

-(instancetype)init
{
    self = [self initWithDelegate:nil];
    return self;
}

-(instancetype)initWithDelegate:(CBIRQueryDelegate *)delegate
{
    self = [super init];
    if ( self ) {
        _delegate = delegate;
    }
    
    return self;
}

@end
