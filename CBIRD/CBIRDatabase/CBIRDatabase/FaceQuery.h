//
//  FaceQuery.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRQuery.h"

@class CIImage, CIFaceFeature;



@interface FaceDataResult : NSObject

// The difference sum of this particular face and the source face.
// This is the order that should be respected by the heap in min heap fashion.
@property (nonatomic) CGFloat differenceSum;

// The document ID of the image that this face exists in.
@property (nonatomic) NSString * imageDocumentID;

@property (nonatomic) NSString * faceUUID;

@property (nonatomic) CGRect faceRect;

@property (nonatomic) NSData * faceJPEGData;

@end




@interface FaceQuery : CBIRQuery

@property (nonatomic, readonly) CIImage * inputFaceImage;
@property (nonatomic, readonly) CIFaceFeature * inputFaceFeature;

// Initializes the query with the source image (e.g. not the face, but the whole thing) and a face feature
//
-(instancetype)initWithFaceImage:(CIImage *)faceImage withFeature:(CIFaceFeature *)faceFeature andDelegate:(id<CBIRQueryDelegate>)delegate NS_DESIGNATED_INITIALIZER;

-(FaceDataResult *)dequeueResult;

@end
