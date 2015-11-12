//
//  FaceQuery.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRQuery.h"

@class CIImage;

@interface FaceQuery : CBIRQuery

@property (nonatomic, readonly) CIImage * inputFaceImage;

-(instancetype)initWithFaceImage:(CIImage *)faceImage andDelegate:(id<CBIRQueryDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@end