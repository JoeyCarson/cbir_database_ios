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

@interface FaceDataHeapContainer

// The difference sum of this particular face and the source face.
// This is the order that should be respected by the heap in min heap fashion.
@property (nonatomic) CGFloat differenceSum;

// The document ID of the image that this face exists in.
@property (nonatomic) NSString * imageDocumentID;

@end


@implementation FaceQuery
{
    NSData * m_inputFaceHistoImageData;
    CFBinaryHeapRef m_minHeap;
}

@synthesize inputFaceImage = _inputFaceImage;
@synthesize inputFaceFeature = _inputFaceFeature;

-(instancetype)initWithDelegate:(id<CBIRQueryDelegate>)delegate
{
    return [self initWithFaceImage:nil withFeature:nil andDelegate:delegate];
}

-(instancetype)initWithFaceImage:(CIImage *)faceImage withFeature:(CIFaceFeature *)faceFeature andDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [super initWithDelegate:delegate];
    if ( self ) {
        _inputFaceImage = faceImage;
        _inputFaceFeature = faceFeature;
        [self buildMinBinHeap];
    }
    return self;
}


CFComparisonResult binaryHeapCompareCallBack( const void *ptr1, const void *ptr2, void *info )
{
    FaceDataHeapContainer * faceData1 = (__bridge FaceDataHeapContainer *)ptr1;
    FaceDataHeapContainer * faceData2 = (__bridge FaceDataHeapContainer *)ptr2;
    
    if ( faceData1.differenceSum < faceData2.differenceSum ) {
        return kCFCompareLessThan; // kCFCompareLessThan if ptr1 is less than ptr2,
    } else if ( faceData1.differenceSum > faceData2.differenceSum ) {
        return kCFCompareGreaterThan; // kCFCompareGreaterThan if ptr1 is greater than ptr2.
    }

    return kCFCompareEqualTo; // kCFCompareEqualTo if ptr1 and ptr2 are equal, or
}


-(void)buildMinBinHeap
{
    if( !m_minHeap ) {
        
        CFBinaryHeapCallBacks callbackStruct = {.version = 0, .retain = NULL, .release = NULL, .copyDescription = NULL, .compare = binaryHeapCompareCallBack};
        m_minHeap = CFBinaryHeapCreate(NULL, 0, &callbackStruct, NULL);
    }
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
            m_inputFaceHistoImageData = inputFaceHistoAttachment.content;
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
// Consider the following approach.  Using two 4x4 block histogram images computing the nearest neighbor
// between e[3] inside the entire histogram training image t[i].  This process can be repeated for each
// training face against each histogram block in the source image.
//
// Expected(e)      Training_i(ti)
// [3][3][3][3]     [0 ][1 ][2 ][3 ]      [e3 - ti0 ][e3 - ti1 ][e3 - ti2 ][e3 - ti3 ]
// [3][3][3][3]  -  [4 ][5 ][6 ][7 ]  =   [e3 - ti4 ][e3 - ti5 ][e3 - ti6 ][e3 - ti7 ]
// [3][3][3][3]     [8 ][9 ][10][11]      [e3 - ti8 ][e3 - ti9 ][e3 - ti10][e3 - ti11]
// [3][3][3][3]     [12][13][14][15]      [e3 - ti12][e3 - ti13][e3 - ti14][e3 - ti15]
//
// 1. Perform the search by iterating through each face list of each image.
// 2. For each face in the face list of the image, find the nearest neighbor by evaluating
//    each input face block against the image, and adding the least resultant value to
//    the running sum (difference) for that face.
// 3. When all images have been iterated, choose the face with the least difference, and
//    the image associated with that face is the best match.  Continue pulling those with
//    the least difference.  Use a CFBinaryHeap and figure out how to use it as a min heap.
//
//
//
-(NSError *)performSearch
{
    // Begin by iterating all documents in the database.
    // TODO: Come up with a better way of indexing names so that we're not actually running through every object ever.
    // It's not a big deal right now since the database only contains faces, but if it were to contain more...
    CBLQuery * allDocsQuery =[[CBIRDatabaseEngine sharedEngine] createAllDocsQuery];
    
    NSError * queryError = nil;
    CBLQueryEnumerator * qEnum = [allDocsQuery run:&queryError];
    
    if ( !queryError ) {
        
        for ( CBLQueryRow * row in qEnum ) {
            
            NSDictionary * p = row.document.properties;
            NSArray * faceDataList = p[kCBIRFaceDataList];

            for ( NSUInteger i = 0; i < faceDataList.count; i++ ) {
                
                
                
                
            }
            
            NSString * fid = p[kCBIRFaceID];
            NSString * histoImageAttachmentID = p[kCBIRHistogramImage];
            CBLAttachment * att = [row.document.currentRevision attachmentNamed:histoImageAttachmentID];
            
            // Now we have a hold of the histogram data.
            NSData * histoImageData = att.content;
            
        }
        
    } else {
        NSLog(@"%s query resulted in error: %@", __FUNCTION__, queryError);
    }
    
    
    
    return queryError;
}





@end
