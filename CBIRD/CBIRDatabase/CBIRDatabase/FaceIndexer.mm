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

@synthesize lbpFilter = _lbpFilter;

-(instancetype)init
{
    self = [super init];
    if ( self ) {
        // Understand that this makes this class no longer immutable as the CIFilter is mutable.
        // If you can share across threads in the future, do so..
        // For instance, if CIKernel does any caching underneath for the same program, then we
        // can create multiple instances of LBPFilter and not worry about performance, then do it.
        // We don't want to pay for recompilation 400 times if we use 400 different instances.
        _lbpFilter = [[LBPFilter alloc] init];
    }
    
    return self;
}

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

    
    // Apply the filter for each face rectangle.  This generates a different
    // outputImage for each face rectangle.
    NSArray * faceFeatures = [ImageUtil detectFaces:image];
    NSLog(@"generateLBPFaces: %lul", (unsigned long)faceFeatures.count);
    for ( CIFaceFeature * feature in faceFeatures ) {

        FaceLBP * f = [self generateLBPFace:image fromFeature:feature];
        [lbpFaceImages addObject:f];
    }
    
    return lbpFaceImages;
}

-(FaceLBP *)generateLBPFace:(CIImage *)inputImage fromFeature:(CIFaceFeature *)feature
{
    _lbpFilter.inputImage = inputImage;
    [_lbpFilter applyToExtent:feature.bounds];
    FaceLBP * f = [[FaceLBP alloc] initWithRect:feature.bounds image:_lbpFilter.outputImage];
    
    return f;
}

// Extracts features from each face in the list and save them to the document.
- (void) extractFeatures:(NSArray<FaceLBP *> *)faces andPersistTo:(CBLUnsavedRevision *)revision
{
    // Array of face data dictionaries.
    NSMutableArray * faceDataList = [[NSMutableArray alloc] init];
 
    // For each face, we shall also keep a full histogram image.  This is necessary so that the
    // query operation doesn't have to continually build the buffer.  It also be may be useful
    // to exclusively use this entire buffer in the future instead of storing the individual
    // block histograms too.
    size_t histoLengthInBytes = 256 * sizeof(float);
    NSUInteger histoImageSize = GRID_HEIGHT_IN_BLOCKS * GRID_WIDTH_IN_BLOCKS * histoLengthInBytes;
    unsigned char * trainingHistoImageBuffer = (unsigned char *) malloc(histoImageSize);
    
    // For each given face image, we need to build a list of histograms over 8x8 regions.
    for ( NSUInteger i = 0; i < faces.count; i++ ) {
        @autoreleasepool {
            
            // Prepare for writing this face's histogram image.
            // Clear the histogram image buffer and point output to [0].
            memset(trainingHistoImageBuffer, 0, sizeof(*trainingHistoImageBuffer));
            unsigned char * outputHistoPointer = trainingHistoImageBuffer;
            
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
            
            // featureIndex identifies the index of the feature in the overall face image.
            NSUInteger featureIndex = 0;
            
            for ( UInt32 blockRow = 0; blockRow < verticalBlockCt; blockRow++ ) {
                
                // blockIndex identfies the index of the block relative to the current row.
            
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
                        float range[] = { -0.1, 256 }; // [0, 255]
                        const float* histRange = { range };
                        cv::calcHist( &channels[0], 1, 0, cv::Mat(), lbpHistogram, 1, &histSize, &histRange, true, false );
                        
                        // Normalize all gray levels to their overall percentage in the region.
                        [self percentizeHistogram:&lbpHistogram blockArea:(block_height * block_width)];
                        
                        // We need to be cognizant of the type of underlying data that OpenCV is producing in the histogram.
                        // We're only aware of 32bit floats.
                        NSAssert(lbpHistogram.type() == CV_32F, @"LBP Histogram type is %d.  Only CV_32F is supported", lbpHistogram.type());
                        
                        // Write the data and total to the CBLDocument.  Might be able to use no-copy, assuming that
                        // CBL itself will eventually copy the data, no need for it twice.  Might be necessary for thread safety.
                        NSString * featureID = [NSString stringWithFormat:@"%@_%u", faceUUID, (unsigned int)featureIndex];
                        NSUInteger sizeOfHistogramData = lbpHistogram.total() * lbpHistogram.elemSize();
                        NSData * histogramData = [NSData dataWithBytes:lbpHistogram.data length:sizeOfHistogramData];
                        [revision setAttachmentNamed:featureID withContentType:MIME_TYPE_OCTET_STREAM content:histogramData];
                        
                        // Also write the histogramData into the histogram image.
                        memcpy(outputHistoPointer, histogramData.bytes, sizeOfHistogramData);
                        outputHistoPointer += sizeOfHistogramData;
                        
                        // Store the feature ID in the list.
                        [featureIdentifiers addObject:featureID];
                        
                        //NSLog(@"pixels");
                        //std::cout << channels[0];
                        
                        //NSLog(@"histogram type: %d elemSize: %zu", lbpHistogram.type(), lbpHistogram.elemSize());
                        //std::cout << lbpHistogram;
                    }
                }
            }
            
            NSData * fullHistoImageData = [NSData dataWithBytes:trainingHistoImageBuffer length:histoImageSize];
            NSString * faceHistoID = [NSString stringWithFormat:@"%@_%@", faceUUID, kCBIRHistogramImage];
            [revision setAttachmentNamed:faceHistoID withContentType:MIME_TYPE_OCTET_STREAM content:fullHistoImageData];
            
            faceData[kCBIRFaceID] = faceUUID;
            faceData[kCBIRFeatureIDList] = featureIdentifiers;
            faceData[kCBIRHistogramImage] = faceHistoID;
            // TODO: Add the full histo image. kCBIRHistogramImage
            [faceDataList addObject:faceData];
            
            if ( buffer ) {
                // Why on Earth wouldn't there be a buffer?
                free(buffer);
                buffer = NULL;
            }
        }
    }
    
    // This buffer is reused for each face histogram image as they're all the same size.
    // Clear it when we're done.
    if ( trainingHistoImageBuffer ) {
        free(trainingHistoImageBuffer);
        trainingHistoImageBuffer = NULL;
    }
    
    if ( faceDataList.count > 0 ) {
        NSMutableDictionary * newProperties = revision.properties;
        newProperties[kCBIRFaceDataList] = faceDataList;
    }
}

// Normalizes the values in the histogram such that each bin (lbp intensity) value is the percentage of the occurrence
// occurence of the color that the bin represents.  This should correct for equal faces at different scales which cause
// the values of each intensity to be scaled to more or less, despite the images being effectively equal.
- (void) percentizeHistogram:(cv::Mat *)lbpHistogram blockArea:(size_t)area
{
    // Recall that cv::normalize(lbpHistogram, lbpHistogram, 0, block_width * block_height, cv::NORM_MINMAX, -1, cv::Mat() );
    // doesn't do the trick.
    
    cv::Mat col = lbpHistogram->col(0);
    for ( int i = 0; i < col.rows; i++ ) {
        float & valRef = col.at<float>(i);
        valRef /= area;
        //NSLog(@"valRef is: %f", valRef);
    }
}

- (NSString *) generateFaceKey
{
    return [NSString stringWithFormat:@"%@%@", FACE_KEY_PREFIX, [NSUUID UUID].UUIDString];
}


@end