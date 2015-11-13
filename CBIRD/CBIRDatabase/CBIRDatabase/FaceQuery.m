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
{
    NSData * inputFaceHistoImageData;
}

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
    
    // Create an LBP for the input face.
    FaceLBP * faceLBP = [faceIndexer generateLBPFace:self.inputFaceImage fromFeature:self.inputFaceFeature];
    NSAssert(faceLBP != nil, @"Face LBP failed generation for FaceQuery input.");
    
    // Create the descriptor object for the input face using the same method that FaceIndexer does.
    [faceIndexer extractFeatures:@[faceLBP] andPersistTo:tempFaceLBPRevision];
    
    NSArray * faceList = tempFaceLBPRevision.properties[kCBIRFaceDataList];
    if ( faceList.count == 1 ) {
        
        NSDictionary * faceData = faceList[0];
        NSString * histoImageID = faceData[kCBIRHistogramImage];
        if ( [tempFaceLBPRevision.attachmentNames containsObject:histoImageID] ) {
            
            // Read the full histo image for the search face and kick off the process to search.
            CBLAttachment * inputFaceHistoAttachment = [tempFaceLBPRevision attachmentNamed:histoImageID];
            inputFaceHistoImageData = inputFaceHistoAttachment.content;
            [self performSearch];
        
            
        } else {
            NSLog(@"faceData attachments doesn't contain histogram image.");
        }
        
    } else {
        NSLog(@"faceList of image must contain only a single face. count: %lu", (unsigned long)faceList.count);
    }
}


// Algorithm:  Maturana's algorithm effectively takes each block of the input face and attempts to find the nearest
// neighboring block (according to Chi-Square similarity) in each training face.  Using the ChiSquareFilter we will
// effectively compute the Chi-Square difference of every block in each training face against one block of the input
// face at a time.  We will do this by leaving the training face histogram image as it is, while building the expected
// image as a grid in which all blocks represent the same block.  Since both images are compatible in block dimensions,
// data type size, and histogram bin count, their Chi-Square difference can be computed, yielding the difference of each
// block in the training histogram image and one block in the expected image.
//
//
// Consider the following approach.  Using two 4x4 block histogram images.
//
// Expected(e)      Training_i(ti)
// [3][3][3][3]     [0 ][1 ][2 ][3 ]      [e3 - ti0 ][e3 - ti1 ][e3 - ti2 ][e3 - ti3 ]
// [3][3][3][3]  -  [4 ][5 ][6 ][7 ]  =   [e3 - ti4 ][e3 - ti5 ][e3 - ti6 ][e3 - ti7 ]
// [3][3][3][3]     [8 ][9 ][10][11]      [e3 - ti8 ][e3 - ti9 ][e3 - ti10][e3 - ti11]
// [3][3][3][3]     [12][13][14][15]      [e3 - ti12][e3 - ti13][e3 - ti14][e3 - ti15]
//
-(NSError *)performSearch
{
    // Begin by iterating all documents in the database.
    // TODO: Come up with a better way of indexing names so that we're not actually running through every object ever.
    
    CBLQuery * allDocsQuery =[[CBIRDatabaseEngine sharedEngine] createAllDocsQuery];
    
    NSError * queryError = nil;
    CBLQueryEnumerator * qEnum = [allDocsQuery run:&queryError];
    
    if ( !queryError ) {
        //for ( CBLQuery * query in alld)
    } else {
        NSLog(@"%s query resulted in error: %@", __FUNCTION__, queryError);
    }
    
    
    
    return queryError;
}



@end
