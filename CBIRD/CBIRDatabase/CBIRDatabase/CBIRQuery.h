//
//  CBIRQuery.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CBIRQueryDelegate;

@interface CBIRQuery : NSObject

@property (nonatomic, readonly, weak) CBIRQueryDelegate * delegate;

-(instancetype)initWithDelegate:(CBIRQueryDelegate *)delegate NS_DESIGNATED_INITIALIZER;


@end
