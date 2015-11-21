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




@class CIFilter;

// The grid size to partition each face into.
#define FACE_INDEXER_HISTOGRAM_BIN_COUNT 256
#define FACE_INDEXER_GRID_WIDTH_IN_BLOCKS 8
#define FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS 8

static const NSString * const kCBIRFaceDataList = @"face_data_list";
static const NSString * const kCBIRFaceID = @"faceID";
static const NSString * const kCBIRFeatureIDList = @"features";
static const NSString * const kCBIRHistogramImage = @"histogram_image_attachment";

@interface FaceIndexer : CBIRIndexer

-(NSArray<FaceLBP *> *) generateLBPFaces:(CIImage *)image;

-(FaceLBP *) generateLBPFace:(CIImage *)inputImage fromFeature:(CIFaceFeature *)feature;

- (void) extractFeatures:(NSArray<FaceLBP *> *)faces andPersistTo:(CBLUnsavedRevision *)revision;

@end
