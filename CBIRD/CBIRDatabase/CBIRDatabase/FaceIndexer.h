//
//  FaceIndexer.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/15/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CBIRDatabase/CBIRDatabase.h>

#import "LBPFilter.h"

@interface FaceLBP : NSObject

@property(nonatomic, readonly, assign) CGRect rect;
@property(nonatomic, readonly) CIImage * lbpImage;

-(instancetype) initWithRect:(CGRect)rect image:(CIImage *)image;

@end




// The grid size to partition each face into.
#define GRID_WIDTH_IN_BLOCKS 8
#define GRID_HEIGHT_IN_BLOCKS 8



static NSString * const FACE_DATA_LIST_DBKEY = @"face_data_list";
static const NSString * const kCBIRFaceID = @"faceID";
static const NSString * const kCBIRFeatureIDList = @"features";

@interface FaceIndexer : CBIRIndexer

@property (nonatomic, readonly) LBPFilter * lbpFilter;

-(NSArray<FaceLBP *> *) generateLBPFaces:(CIImage *)image;

-(FaceLBP *) generateLBPFace:(CIImage *)inputImage fromFeature:(CIFaceFeature *)feature;

- (void) extractFeatures:(NSArray<FaceLBP *> *)faces andPersistTo:(CBLUnsavedRevision *)revision;

@end
