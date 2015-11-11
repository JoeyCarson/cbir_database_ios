//
//  FaceQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "FaceQuery.h"

@implementation FaceQuery

@synthesize faceImage = _faceImage;

-(instancetype)initWithDelegate:(CBIRQueryDelegate *)delegate
{
    self = [self initWithDelegate:delegate];
    return self;
}

-(instancetype)initWithFaceImage:(CIImage *)faceImage andDelegate:(CBIRQueryDelegate *)delegate
{
    self = [super initWithDelegate:delegate];
    if ( self ) {
        _faceImage = faceImage;
    }
    return self;
}

@end
