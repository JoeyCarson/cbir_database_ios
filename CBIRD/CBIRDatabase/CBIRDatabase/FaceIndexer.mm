//
//  FaceIndexer.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/15/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <opencv2/opencv.hpp>
#import <CouchbaseLite/CouchbaseLite.h>

#import "CBIRDocument.h"
#import "LBPFilter.h"
#import "FaceIndexer.h"
#import "ImageUtil.h"
#import "CBLUtil.h"


NSString * FACE_KEY_PREFIX = @"face_";


// FaceIndexer internal class to hang onto face related properties.
@interface FaceLBP : NSObject

@property(nonatomic, readonly, assign) CGRect rect;
@property(nonatomic, readonly) CIImage * lbpImage;

-(instancetype) initWithRect:(CGRect)rect image:(CIImage *)image;

@end

@implementation FaceLBP

@synthesize rect = _rect;
@synthesize lbpImage = _lbpImage;

-(instancetype) initWithRect:(CGRect)rect image:(CIImage *)image
{
    self = [super init];
    if ( self ) {
        _rect = rect;
        _lbpImage = image;
    }
    return self;
}

@end




@implementation FaceIndexer

-(CBIRIndexResult *)indexImage:(CBIRDocument *)document cblDocument:(CBLDocument *)cblDoc
{
    // 1.  Filter the image using the LBP filter.
    NSArray<FaceLBP *> * lbpFaces = [self generateLBPFaces:document.imageResource];
    
    [self extractFeatures:lbpFaces andPersistTo:cblDoc];
    
    // Return the result with a preview of the filtered image for the UI to use for funzies.
    //UIImage * i = [UIImage imageWithCIImage:(lbpFaces.count ? lbpFaces[0] : nil) scale:1.0 orientation:UIImageOrientationUp];
    CBIRIndexResult * result = [[CBIRIndexResult alloc] initWithResult:YES filteredImage:nil];
    return result;
}


-(NSArray<FaceLBP *> *) generateLBPFaces:(CIImage *)image
{
    NSMutableArray * lbpFaceImages = [[NSMutableArray alloc] init];
    
    // Instantiate the filter and set the input image to the instance we just created.
    LBPFilter * lbpf = [[LBPFilter alloc] init];
    lbpf.inputImage = image;
    
    // Apply the filter for each face rectangle.  This generates a different
    // outputImage for each face rectangle.
    NSArray * faceFeatures = [ImageUtil detectFaces:image];
    for ( CIFaceFeature * feature in faceFeatures ) {
        [lbpf applyToExtent:feature.bounds];
        FaceLBP * f = [[FaceLBP alloc] initWithRect:feature.bounds image:lbpf.outputImage];
        [lbpFaceImages addObject:f];
    }
    
    return lbpFaceImages;
}

// Extracts features from each face in the list and save them to the document.
- (void) extractFeatures:(NSArray<FaceLBP *> *)faces andPersistTo:(CBLDocument *)doc
{
    #define BLOCK_SIZE 16
    // Allocate the block to hold 4 bytes per pixel.
    unsigned char * buffer = (unsigned char *) malloc(BLOCK_SIZE * BLOCK_SIZE * 4);
    
    // Array of face data dictionaries.
    NSMutableArray * faceDataList = [[NSMutableArray alloc] init];
    
    CBLUnsavedRevision * revision = [doc newRevision];
    
        // For each given face image, we need to build a list of 8x8 histograms of the
    for ( NSUInteger i = 0; i < faces.count; i++ ) {
        
        // Identifier of this particular face.
        NSString * faceUUID = [self generateFaceKey];
        
        // Render the face LBP and get a pointer to the underlying data buffer.
        FaceLBP * face = faces[i];
        
        // Dimensions of the face in pixels.
        CGFloat width  = face.lbpImage.extent.size.width;
        CGFloat height = face.lbpImage.extent.size.height;
        NSData * pixelData = [ImageUtil copyPixelData:face.lbpImage];
        
        // Round up the number of blocks and rows to ensure that we consume the entire image.
        UInt32 horizontalBlockCt = ceil(width / BLOCK_SIZE);
        UInt32 verticalBlockCt   = ceil(height / BLOCK_SIZE);
        
        // List of the names of feature ID's.
        NSMutableArray<NSString *> * featureIdentifiers = [[NSMutableArray alloc] init];
        NSMutableDictionary * faceData = [[NSMutableDictionary alloc] init];
        
        NSUInteger featureIndex = 0;
        
        for ( UInt32 blockRow = 0; blockRow < verticalBlockCt; blockRow++ ) {
            
            // blockIndex identfies the index of the block relative to the current row.
            // featureIndex identifies the index of the feature in the overall face image.
            
            for ( UInt32 blockIndex = 0; blockIndex < horizontalBlockCt; blockIndex++, featureIndex++ ) {
                
                @autoreleasepool {
                
                    // Extract the rectangle. Make sure that the image and block sizes accounts for 4 bytes per pixel.
                    CGSize faceSize = CGSizeMake(4 * face.lbpImage.extent.size.width, face.lbpImage.extent.size.height);
                    CGRect rect = CGRectMake(blockIndex, blockRow, 4 * BLOCK_SIZE, BLOCK_SIZE);
                    [ImageUtil extractRect:rect fromData:pixelData ofSize:faceSize intoBuffer:buffer];
                    
                    // Load the rectangle into a cv matrix and split it up into channels.
                    // We only need the first one.  Ideally need to figure out how to output single byte pixels.
                    cv::Mat blockPixels(BLOCK_SIZE, BLOCK_SIZE, CV_8UC4, buffer, sizeof(*buffer));
                    std::vector<cv::Mat> channels;
                    cv::split(blockPixels, channels);
                    
                    // Calculate the histogram.
                    cv::Mat lbpHistogram;
                    int histSize = 256;
                    float range[] = { 0, 256 } ;
                    const float* histRange = { range };
                    cv::calcHist( &channels[0], 1, 0, cv::Mat(), lbpHistogram, 1, &histSize, &histRange, true, false );
                    
                    
                    // Write the data and total to the CBLDocument.  Might be able to use no-copy, assuming that
                    // CBL itself will eventually copy the data, no need for it twice.  Might be necessary for thread safety.
                    NSString * featureID = [NSString stringWithFormat:@"%@_%u", faceUUID, (unsigned int)featureIndex];
                    NSData * histogramData = [NSData dataWithBytes:lbpHistogram.data length:lbpHistogram.total()];
                    [revision setAttachmentNamed:featureID withContentType:MIME_TYPE_OCTET_STREAM content:histogramData];
                    
                    // Store the feature ID in the list.
                    [featureIdentifiers addObject:featureID];
                    
                    //NSLog(@"pixels");
                    //std::cout << channels[0];
                    
                    //NSLog(@"histogram");
                    //std::cout << lbpHistogram;
                }
            }
        }
        
        faceData[@"id"] = faceUUID;
        faceData[@"features"] = featureIdentifiers;
        [faceDataList addObject:faceData];
    }
    
    if ( faceDataList.count > 0 ) {
        NSError * error = nil;
        
        NSMutableDictionary * newProperties = revision.properties;
        
        newProperties[FACE_DATA_LIST_DBKEY] = faceDataList;
        [revision save:&error];
        
        if ( error ) {
            NSLog(@"%s error saving face data list: %@", __FUNCTION__, error);
        }
    }
    
    free(buffer);
}

- (NSString *) generateFaceKey
{
    return [NSString stringWithFormat:@"%@%@", FACE_KEY_PREFIX, [NSUUID UUID].UUIDString];
}


@end
