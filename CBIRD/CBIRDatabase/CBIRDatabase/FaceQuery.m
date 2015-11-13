//
//  FaceQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "FaceQuery.h"
#import "FaceIndexer.h"
#import "CBIRDocument.h"

@implementation FaceQuery

@synthesize inputFaceImage = _inputFaceImage;
@synthesize inputFaceFeature = _inputFaceFeature;

-(instancetype)initWithDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [self initWithDelegate:delegate];
    return self;
}

-(instancetype)initWithFaceImage:(CIImage *)faceImage withFeature:(CIFaceFeature *)faceFeature andDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [super initWithDelegate:delegate];
    if ( self ) {
        _inputFaceImage = faceImage;
        _inputFaceFeature = faceFeature;
    }
    return self;
}

-(void)run
{
    NSLog(@"%s executing.", __FUNCTION__);
    // Retrieve the desired Indexer.  It must be registered and it must be a FaceIndexer, lest we give up.
    const CBIRIndexer * indexer = [[CBIRDatabaseEngine sharedEngine] getIndexer:NSStringFromClass([FaceIndexer class])];
    NSAssert(indexer != nil && [indexer class] == [FaceIndexer class], @"%s failed to get FaceIndexer resource.  Object: %@", __FUNCTION__, indexer);

    FaceIndexer * faceIndexer = (FaceIndexer *)indexer;
    NSString * tempQueryID = @"face_query_temp";
    CBLDocument * dbDocument = [[CBIRDatabaseEngine sharedEngine] newDocument:tempQueryID];
    CBLUnsavedRevision * tempFaceLBPRevision = [dbDocument newRevision];
    
    // Create an LBP 
    FaceLBP * faceLBP = [faceIndexer generateLBPFace:self.inputFaceImage fromFeature:self.inputFaceFeature];
    NSAssert(faceLBP != nil, @"Face LBP failed generation for FaceQuery input.");
    
    // Create the descriptor object for the input face using the same method that FaceIndexer does.
    [faceIndexer extractFeatures:@[faceLBP] andPersistTo:tempFaceLBPRevision];
    
    NSArray * faceList = tempFaceLBPRevision.properties[kCBIRFaceDataList];
    if ( faceList.count == 1 ) {
        
        NSDictionary * faceData = faceList[0];
        NSString * histoImageID = faceData[kCBIRHistogramImage];
        if ( [tempFaceLBPRevision.attachmentNames containsObject:histoImageID] ) {
            
            CBLAttachment * inputFaceHistoAttachment = [tempFaceLBPRevision attachmentNamed:histoImageID];
            NSData * inputFaceHistoImageData = inputFaceHistoAttachment.content;
            
        } else {
            NSLog(@"faceData attachments doesn't contain histogram image.");
        }
        
    } else {
        NSLog(@"faceList of image must contain only a single face. count: %lu", (unsigned long)faceList.count);
    }
}



@end
