//
//  FaceQuery.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRQuery.h"

@class CIImage, CIFaceFeature;

@interface FaceQuery : CBIRQuery

@property (nonatomic, readonly) CIImage * inputFaceImage;
@property (nonatomic, readonly) CIFaceFeature * inputFaceFeature;

// Initializes the query with the source image (e.g. not the face, but the whole thing) and a face feature
//
-(instancetype)initWithFaceImage:(CIImage *)faceImage withFeature:(CIFaceFeature *)faceFeature andDelegate:(id<CBIRQueryDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@end
