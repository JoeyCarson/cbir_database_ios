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

-(CBLUnsavedRevision *)indexImage:(CBIRDocument *)document cblDocument:(CBLDocument *)cblDoc
{
    // 1.  Filter the image using the LBP filter.
    NSArray<FaceLBP *> * lbpFaces = [self generateLBPFaces:document.imageResource];
    
    CBLUnsavedRevision * result = [cblDoc newRevision];
    [self extractFeatures:lbpFaces andPersistTo:result];
    
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
    NSLog(@"generateLBPFaces: %lul", (unsigned long)faceFeatures.count);
    for ( CIFaceFeature * feature in faceFeatures ) {
        [lbpf applyToExtent:feature.bounds];
        FaceLBP * f = [[FaceLBP alloc] initWithRect:feature.bounds image:lbpf.outputImage];
        [lbpFaceImages addObject:f];
    }
    
    return lbpFaceImages;
}

// Extracts features from each face in the list and save them to the document.
- (void) extractFeatures:(NSArray<FaceLBP *> *)faces andPersistTo:(CBLUnsavedRevision *)revision
{
    // The grid size to partition each face into.
    #define GRID_WIDTH_IN_BLOCKS 16
    #define GRID_HEIGHT_IN_BLOCKS 16
    
    // Array of face data dictionaries.
    NSMutableArray * faceDataList = [[NSMutableArray alloc] init];
    
    // For each given face image, we need to build a list of 8x8 histograms of the
    for ( NSUInteger i = 0; i < faces.count; i++ ) {
        @autoreleasepool {
            // Identifier of this particular face.
            NSString * faceUUID = [self generateFaceKey];
            
            // Render the face LBP and get a pointer to the underlying data buffer.
            FaceLBP * face = faces[i];
            
            // Dimensions of the face and pixel buffer.
            CGFloat width  = face.lbpImage.extent.size.width;
            CGFloat height = face.lbpImage.extent.size.height;
            NSData * pixelData = [ImageUtil copyPixelData:face.lbpImage];
            
            // The number of blocks we're slicing the image into.
            UInt32 horizontalBlockCt = GRID_WIDTH_IN_BLOCKS;
            UInt32 verticalBlockCt   = GRID_HEIGHT_IN_BLOCKS;
            
            // TODO: Come up with a safe (e.g. not overstepping the array) way to partition
            // the image such that we aren't losing precision in width per block.
            // If we rounded up for the fraction of the pixel, it will make the block widths
            // add up to greater than the actual width of the buffer.
            // Interesting little problem.  But just keep it mildly imprecise and safe for now.
            UInt32 block_width  = width / horizontalBlockCt;
            UInt32 block_height = height / verticalBlockCt;
            
            // Allocate the block to hold 4 bytes per pixel.
            unsigned char * buffer = (unsigned char *) malloc(block_width * block_height * 4);
            
            // List of the names of feature ID's.
            NSMutableArray<NSString *> * featureIdentifiers = [[NSMutableArray alloc] init];
            NSMutableDictionary * faceData = [[NSMutableDictionary alloc] init];
            
            // The size of the face.
            CGSize faceSize = CGSizeMake(4 * width, height);
            
            // Extract features blocks from each row as such.
            // [0 ][1 ][2 ][3 ] 0
            // [4 ][5 ][6 ][7 ] 1             example: a 4x4 grid.
            // [8 ][9 ][10][11] 2             See GRID_WIDTH_IN_BLOCKS
            // [12][13][14][15] 3             and GRID_HEIGHT_IN_BLOCKS.
            //  0   1   2   3
            
            // The index of each block in the grid.
            NSUInteger featureIndex = 0;
            
            for ( UInt32 blockRow = 0; blockRow < verticalBlockCt; blockRow++ ) {
                
                // blockIndex identfies the index of the block relative to the current row.
                // featureIndex identifies the index of the feature in the overall face image.
                
                for ( UInt32 blockIndex = 0; blockIndex < horizontalBlockCt; blockIndex++, featureIndex++ ) {
                    
                    @autoreleasepool {
                        
                        // Extract the rectangle. Make sure that the image and block sizes accounts for 4 bytes per pixel.
                        CGRect rect = CGRectMake(blockIndex, blockRow, 4 * block_width, block_height);
                        [ImageUtil extractRect:rect fromData:pixelData ofSize:faceSize intoBuffer:buffer];
                        
                        // Load the rectangle into a cv matrix and split it up into channels.
                        // We only need the first one.  Ideally need to figure out how to output single byte pixels.
                        cv::Mat blockPixels(block_width, block_height, CV_8UC4, buffer, sizeof(*buffer));
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
                        
                        // It's a good idea to come up with a way to flush when the histograms become too many.
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
            
            if ( buffer ) {
                // Why on Earth wouldn't there be a buffer?
                free(buffer);
            }
        }
    }
    
    if ( faceDataList.count > 0 ) {
        NSMutableDictionary * newProperties = revision.properties;
        newProperties[FACE_DATA_LIST_DBKEY] = faceDataList;
    }
}

- (NSString *) generateFaceKey
{
    return [NSString stringWithFormat:@"%@%@", FACE_KEY_PREFIX, [NSUUID UUID].UUIDString];
}


@end
