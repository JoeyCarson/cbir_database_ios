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
    // Retrieve the desired Indexer.
    FaceIndexer * faceIndexer = nil;
    const CBIRIndexer * indexer = [[CBIRDatabaseEngine sharedEngine] getIndexer:NSStringFromClass([FaceIndexer class])];
    
    if ( [indexer class] == [FaceIndexer class]) {
        faceIndexer = (FaceIndexer *)indexer;
        
        NSString * tempQueryID = @"face_query_temp";
        CBLDocument * dbDocument = [[CBIRDatabaseEngine sharedEngine] newDocument:tempQueryID];
        CBLUnsavedRevision * tempFaceLBPRevision = [dbDocument newRevision];
        
        FaceLBP * faceLBP = [faceIndexer generateLBPFace:self.inputFaceImage fromFeature:self.inputFaceFeature];
        NSAssert(faceLBP != nil, @"Face LBP failed generation for FaceQuery input.");
        
        NSArray<FaceLBP *> * faces = @[faceLBP];
        [faceIndexer extractFeatures:faces andPersistTo:tempFaceLBPRevision];
        
    }
}



@end
