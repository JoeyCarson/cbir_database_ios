//
//  FaceQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
#import <CouchbaseLite/CouchbaseLite.h>
#import <opencv2/opencv.hpp>

#import "FaceQuery.h"
#import "FaceIndexer.h"
#import "CBIRDocument.h"
#import "ChiSquareFilter.h"

@interface FaceDataHeapContainer : NSObject

// The difference sum of this particular face and the source face.
// This is the order that should be respected by the heap in min heap fashion.
@property (nonatomic) CGFloat differenceSum;

// The document ID of the image that this face exists in.
@property (nonatomic) NSString * imageDocumentID;

@property (nonatomic) NSString * faceUUID;

@end

@implementation FaceDataHeapContainer

@synthesize differenceSum = _differenceSum;
@synthesize imageDocumentID = _imageDocumentID;
@synthesize faceUUID = _faceUUID;

@end




// TODO:  This class could use some optimization.  For one, eventually remove the usage of the individual fragments
// and simply read the associated from the whole histogram image, which will allow us to stop saving the indivudual
// fragments, saving storage.  In the meantime though, don't let premature optimization tempation slow you down!!
@implementation FaceQuery
{
    CFBinaryHeapRef m_minHeap;
    CBLRevision * m_inputFaceLBPRevision; // An LBP face revision generated for the input face.  DO NOT PERSIST IN DATABASE!!
    ChiSquareFilter * m_chiSquareFilter;
    CIContext * m_chiSquareRenderingContext;
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
        // It's possible that we may need to add a backing dictionary to retain pointers.  We'll see.
        CFBinaryHeapCallBacks callbackStruct = {.version = 0, .retain = NULL, .release = NULL, .copyDescription = NULL, .compare = binaryHeapCompareCallBack};
        m_minHeap = CFBinaryHeapCreate(NULL, 0, &callbackStruct, NULL);
    }
}

-(ChiSquareFilter *)chiSquareFilter
{
    if ( !m_chiSquareFilter ) {
        m_chiSquareFilter = [[ChiSquareFilter alloc] init];
    }
    
    return m_chiSquareFilter;
}

// This is the chi square rendering context.  Unfortunately I can't quite figure out
// how to get the data from CoreImage in single channel format without corrupting the
// data by doing what looks to be
-(CIContext *)chiSquareRenderingContext
{
    if ( !m_chiSquareRenderingContext ) {
        
        // Create the rendering context such that it doesn't do any color space
        // conversions and represent pixel data as a single component floats per pixel.
        //CGColorSpaceRef ref = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        NSDictionary * options = @{//kCIContextOutputColorSpace:CFBridgingRelease(ref),
                                   kCIContextOutputColorSpace:[NSNull null],
                                   kCIContextWorkingColorSpace:[NSNull null],
                                   kCIContextUseSoftwareRenderer:[NSNumber numberWithBool:NO]
                                    };
        // kCIContextWorkingFormat:[NSNumber numberWithInt:kCIFormatRf]
        m_chiSquareRenderingContext = [CIContext contextWithOptions:options];
    }
    
    return m_chiSquareRenderingContext;
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
    m_inputFaceLBPRevision = [dbDocument newRevision];
    
    // Create an LBP for the input face.
    FaceLBP * faceLBP = [faceIndexer generateLBPFace:self.inputFaceImage fromFeature:self.inputFaceFeature];
    NSAssert(faceLBP != nil, @"Face LBP failed generation for FaceQuery input.");
    
    // Create the descriptor object for the input face using the same method that FaceIndexer does.
    [faceIndexer extractFeatures:@[faceLBP] andPersistTo:m_inputFaceLBPRevision];
    
    NSArray * faceList = m_inputFaceLBPRevision.properties[kCBIRFaceDataList];
    if ( faceList.count == 1 ) {
        
        NSDictionary * faceData = faceList[0];
        NSString * histoImageID = faceData[kCBIRHistogramImage];
        if ( [m_inputFaceLBPRevision.attachmentNames containsObject:histoImageID] ) {
            
            // Read the full histo image for the search face and kick off the process to search.
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
            NSString * faceID = p[kCBIRFaceID];
            NSArray * faceDataList = p[kCBIRFaceDataList];
            
            // For each face in the list,
            for ( NSUInteger i = 0; i < faceDataList.count; i++ ) {
                
                NSDictionary * faceData = faceDataList[i];
                
                FaceDataHeapContainer * tFace = [[FaceDataHeapContainer alloc] init];
                tFace.differenceSum = [self computeInputFaceDifferenceAgainst:faceData fromDoc:row.document];
                tFace.imageDocumentID = row.document.documentID;
                tFace.faceUUID = faceID;
                
                // Add the face object into the binary heap.
                CFBinaryHeapAddValue(m_minHeap, CFBridgingRetain(tFace));
            }
            
        }
        
    } else {
        NSLog(@"%s query resulted in error: %@", __FUNCTION__, queryError);
    }
    
    
    
    return queryError;
}



-(CGFloat) computeInputFaceDifferenceAgainst:(NSDictionary *)trainFaceData fromDoc:(CBLDocument *)trainDoc
{
    CGFloat difference = 0;
    
    NSArray * inFaceList = m_inputFaceLBPRevision.properties[kCBIRFaceDataList];
    NSAssert(inFaceList.count <= 1, @"Input image has more than one face!  Nooo!!");
    
    //
    NSDictionary * inputFaceData = inFaceList[0];
    NSDictionary * inputFeatureList = inputFaceData[kCBIRFeatureIDList];
    NSArray * trainingFaceFeatures = trainFaceData[kCBIRFeatureIDList];
    
    for ( NSString * featureID in inputFeatureList ) {
        
        CBLAttachment * featureAtt = [m_inputFaceLBPRevision attachmentNamed:featureID];
        NSAssert(featureAtt != nil ,@"One of the feature attributes came out nil??");
        NSData * currenInputFeatureHisto = featureAtt.content;
        CGFloat localLeast = 0;
        
        for ( NSString * trainFeatureID in trainingFaceFeatures ) {
        
            CBLAttachment * trainFeature = [trainDoc.currentRevision attachmentNamed:trainFeatureID];
            NSData * trainingFeatureHisto = trainFeature.content;
            CGFloat tempDiff = [self diffHistogram:currenInputFeatureHisto againstTraining:trainingFeatureHisto];
            
            // Update the localLeast if the new least is less than it is.
            if ( tempDiff < localLeast ) {
                localLeast = tempDiff;
            }
        }
        
        difference += localLeast;
        NSLog(@"squirt");
    }
    
    
    return difference;
}

-(CGFloat)diffHistogram:(NSData *)expected againstTraining:(NSData *)training
{
    CGFloat difference = 0;
    cv::Mat exp(1, FACE_INDEXER_HISTOGRAM_BIN_COUNT, CV_32F, (void*)expected.bytes, expected.length );
    cv::Mat  tr(1, FACE_INDEXER_HISTOGRAM_BIN_COUNT, CV_32F, (void*)training.bytes, training.length);
    
    difference = cv::compareHist(exp, tr, CV_COMP_CHISQR);
    NSLog(@"diffHistogram: %d", difference);
    return difference;
}

-(CIImage *)loadHisto:(NSString * )histoImageAttachmentID fromDocument:(CBLDocument *)doc
{
    size_t histoBlockSizeInBytes = FACE_INDEXER_HISTOGRAM_BIN_COUNT * sizeof(float);
    CBLAttachment * att = [[doc currentRevision] attachmentNamed:histoImageAttachmentID];
    NSData * histoImageData = att.content;
    CGSize histoImageSize = CGSizeMake(FACE_INDEXER_HISTOGRAM_BIN_COUNT * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS, FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS);
    
    CIImage * image = [CIImage imageWithBitmapData:histoImageData
                                       bytesPerRow:(histoBlockSizeInBytes * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS)
                                              size:histoImageSize
                                            format:kCIFormatRf
                                        colorSpace:nil];
    
    return image;
}















// Backup of where the parallel chi square implementation was.
//
//

//-(CGFloat) computeDifferenceAgainstInput:(CIImage *)trainingImage
//{
//    
//    NSArray * faceList = m_inputFaceLBPRevision.properties[kCBIRFaceDataList];
//    if ( faceList.count > 0 )
//    {
//        NSDictionary * faceData = faceList[0];
//        NSArray * features = faceData[kCBIRFeatureIDList];
//        
//        for ( NSString * featureID in features ) {
//            
//            // First generate the expected image (redundant image for the current featureID block).
//            CIImage * expected = [self loadRedundantBlockHIstoImage:featureID];
//            
//            ChiSquareFilter * csf = [self chiSquareFilter];
//            csf.binCount = FACE_INDEXER_HISTOGRAM_BIN_COUNT;
//            csf.expectedImage = expected;
//            csf.trainingImage = trainingImage;
//            
//            // Compute the difference first.  Then render it.
//            CIImage * csfDifference = csf.outputImage;
//            
//            // Copy the buffer and inspect it.
//            NSData * renderedData = [ImageUtil copyPixelData:csfDifference withContext:[self chiSquareRenderingContext]];
//            
//            NSLog(@"squirt");
//        }
//        
//    }
//    
//    
//    return 0.0;
//}



// Loads the histogram image associated with the given attachment name from the given CBLDocument.
//-(CIImage *)loadHisto:(NSString * )histoImageAttachmentID fromDocument:(CBLDocument *)doc
//{
//    size_t histoBlockSizeInBytes = FACE_INDEXER_HISTOGRAM_BIN_COUNT * sizeof(float);
//    CBLAttachment * att = [[doc currentRevision] attachmentNamed:histoImageAttachmentID];
//    NSData * histoImageData = att.content;
//    CGSize histoImageSize = CGSizeMake(FACE_INDEXER_HISTOGRAM_BIN_COUNT * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS, FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS);
//    
//    CIImage * image = [CIImage imageWithBitmapData:histoImageData
//                                       bytesPerRow:(histoBlockSizeInBytes * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS)
//                                              size:histoImageSize
//                                            format:kCIFormatRf
//                                        colorSpace:nil];
//    
//    return image;
//}




// Loads and returns a CIImage histogram image, such that all blocks are populated with the histogram
// stored in the input face feature attachments, identified by the given featureID string.
// TODO: In the future, manually crop the histogram block out of the input histogram image itself
// instead of reading the fragment from the input data, as we want to not store it during the indexing step
// to improve storage requirements and indexing performance.
//-(CIImage *) loadRedundantBlockHIstoImage:(NSString *)featureID
//{
//    // Only do all of this if the CIImage isn't already in the cache.
//    CBLAttachment * histogramAttachment = [m_inputFaceLBPRevision attachmentNamed:featureID];
//    NSData * histoData = histogramAttachment.content;
//    size_t histoBlockSizeInBytes = FACE_INDEXER_HISTOGRAM_BIN_COUNT * sizeof(float);
//    size_t bufferSize = FACE_INDEXER_GRID_WIDTH_IN_BLOCKS * FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS * histoBlockSizeInBytes;
//    void * redundantBlockHistoImageBuffer = malloc(bufferSize);
//    void * outputPointer = redundantBlockHistoImageBuffer;
//    
//    NSUInteger totalBlocks = FACE_INDEXER_GRID_WIDTH_IN_BLOCKS * FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS;
//    for ( NSUInteger blockIndex = 0; blockIndex < totalBlocks; blockIndex++ ) {
//        memcpy(outputPointer, histoData.bytes, histoBlockSizeInBytes);
//        outputPointer += histoBlockSizeInBytes;
//    }
//    
//    NSData * outData = [[NSData alloc] initWithBytes:redundantBlockHistoImageBuffer length:bufferSize];
//    CGSize histoImageDims = CGSizeMake(FACE_INDEXER_HISTOGRAM_BIN_COUNT * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS, FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS);
//    
//    CIImage * img = [CIImage imageWithBitmapData:outData
//                                     bytesPerRow:(histoBlockSizeInBytes * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS)
//                                            size:histoImageDims
//                                          format:kCIFormatRf
//                                      colorSpace:nil];
//    
//    
//    return img;
//}

@end