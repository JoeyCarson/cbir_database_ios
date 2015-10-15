//
//  CBIRIndexer.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
#import "CBIRIndexer.h"


@implementation CBIRIndexResult

@synthesize indexResult = _indexResult;
@synthesize filteredImage = _filteredImage;

-(instancetype)initWithResult:(BOOL)result filteredImage:(UIImage *)image
{
    self = [super init];
    if ( self ) {
        _indexResult = result;
        _filteredImage = image;
    }
    
    return self;
}

@end


@implementation CBIRIndexer

-(CBIRIndexResult *)indexImage:(CBIRDocument *)document
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
