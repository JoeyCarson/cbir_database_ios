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
#import "DoGFilter.h"
#import "FaceIndexer.h"
#import "ImageUtil.h"
#import "CBLUtil.h"


NSString * FACE_KEY_PREFIX = @"face_";


@implementation FaceLBP

@synthesize faceRect = _faceRect;
@synthesize lbpImage = _lbpImage;
@synthesize croppedFaceImage = _croppedFaceImage;

-(instancetype) initWithRect:(CGRect)rect image:(CIImage *)lbpImage croppedFaceImage:(CIImage *)croppedFaceImage
{
    self = [super init];
    if ( self ) {
        _faceRect = rect;
        _lbpImage = lbpImage;
        _croppedFaceImage = croppedFaceImage;
    }
    return self;
}

@end




@implementation FaceIndexer
{
    CIFilter * _affineFilter;
    CIFilter * _cropFilter;
    CIFilter * _gammaAdjustFilter;
    DoGFilter * _dogFilter;
    LBPFilter * _lbpFilter;
}

// Synthesize any properties here.

-(instancetype)init
{
    self = [super init];
    if ( self ) {
        // Understand that this makes this class no longer immutable as the CIFilter is mutable.
        // If you can share across threads in the future, do so..
        // For instance, if CIKernel does any caching underneath for the same program, then we
        // can create multiple instances of LBPFilter and not worry about performance, then do it.
        // We don't want to pay for recompilation 400 times if we use 400 different instances.
        _affineFilter = [CIFilter filterWithName:@"CIAffineTransform"];
        _cropFilter = [CIFilter filterWithName:@"CICrop"];
        _gammaAdjustFilter = [CIFilter filterWithName:@"CIGammaAdjust"];
        _lbpFilter = [[LBPFilter alloc] init];
        _dogFilter = [[DoGFilter alloc] init];
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
    
    // Before we retrieve face rectangles, we need to properly orient the image.
    // TODO: Refactor this into an ImageUtil method?
    CGFloat rotationAngle = [ImageUtil resolveRotationAngle:image];
    CGAffineTransform rotateXForm = CGAffineTransformMakeRotation([ImageUtil degreesToRadians:rotationAngle]);
    NSValue * encodedTransform = [NSValue valueWithBytes:&rotateXForm objCType:@encode(CGAffineTransform)];
    [_affineFilter setValue:encodedTransform forKey:@"inputTransform"];
    [_affineFilter setValue:image forKey:@"inputImage"];
    CIImage * rotatedImage = _affineFilter.outputImage;
    
    // Apply the filter for each face rectangle.  This generates a different
    // outputImage for each face rectangle.
    NSArray * faceFeatures = [ImageUtil detectFaces:rotatedImage];
    NSLog(@"generateLBPFaces: %lul", (unsigned long)faceFeatures.count);
    for ( CIFaceFeature * feature in faceFeatures ) {
        NSLog(@"genearting with feature: angle: %f", feature.faceAngle);
        FaceLBP * f = [self generateLBPFace:rotatedImage fromFeature:feature];
        [lbpFaceImages addObject:f];
    }
    
    return lbpFaceImages;
}

-(FaceLBP *)generateLBPFace:(CIImage *)inputImage fromFeature:(CIFaceFeature *)feature
{
    // We might need to consier potentially rotating the face image so that we're always matching from (0, 0).
    // Rotate the image according to the face angle.
    CGAffineTransform rotateXForm = CGAffineTransformMakeRotation([ImageUtil degreesToRadians:feature.faceAngle]);
    NSValue * encodedTransform = [NSValue valueWithBytes:&rotateXForm objCType:@encode(CGAffineTransform)];
    [_affineFilter setValue:encodedTransform forKey:@"inputTransform"];
    [_affineFilter setValue:inputImage forKey:@"inputImage"];
    CIImage * faceRotatedImage = _affineFilter.outputImage;
    
    CGRect rotatedRect = CGRectApplyAffineTransform(feature.bounds, rotateXForm);
    // First crop out the face.
    [_cropFilter setValue:faceRotatedImage forKey:@"inputImage"];
    [_cropFilter setValue:[CIVector vectorWithCGRect:rotatedRect] forKey:@"inputRectangle"];
    CIImage * croppedImage = _cropFilter.outputImage;

    
    // Perform preprocessing then LBP.
    // 1. Gamma adjustment.
    // Maturnana - Gamma correction to enhance the dynamic range of dark regions and compress light areas and highlights. We use =0.2.
    // Not sure what the f CIAttributeTypeScalar (mentioned in documentation) is.  But float is accepted.
    NSNumber * gammaExponent = [NSNumber numberWithFloat:0.2];
    [_gammaAdjustFilter setValue:croppedImage forKey:@"inputImage"];
    [_gammaAdjustFilter setValue:gammaExponent forKey:@"inputPower"];
    CIImage * gammaAdjustedImage = _gammaAdjustFilter.outputImage;
    
    // 2. DoG.
    // Maturana - Difference of Gaussians (DoG) filtering that acts as a “band pass”, partially suppressing high frequency
    // noise and low frequency illumination variation. For the width of the Gaussian kernels we use  0 = 1.0 and  1 = 2.0.
    _dogFilter.rad1 = 1.0;
    _dogFilter.rad2 = 2.0;
    _dogFilter.inputImage = gammaAdjustedImage;
    CIImage * dogImage = _dogFilter.outputImage;
    
    // 3. Step number 3, I can't understand for the life of me.  .Not sure if it relates to the incorrect results or if it's even necessary.
    // See Maturana's algorithm.
    
    // Apply the LBP filter.
    _lbpFilter.inputImage = dogImage;
    CIImage * outImage = _lbpFilter.outputImage;
    
    
    //[ImageUtil dumpDebugImage:croppedImage];
    FaceLBP * f = [[FaceLBP alloc] initWithRect:feature.bounds image:outImage croppedFaceImage:croppedImage];
    
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
    NSUInteger histoImageSize = FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS * FACE_INDEXER_GRID_WIDTH_IN_BLOCKS * histoLengthInBytes;
    unsigned char * trainingHistoImageBuffer = (unsigned char *) malloc(histoImageSize);
    
    // For each given face image, we need to build a list of histograms over 8x8 regions.
    // TODO:  CIAreaHistogram looks like a good parallel candidate to replace this manual method with.  Investigate it!
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
            UInt32 horizontalBlockCt = FACE_INDEXER_GRID_WIDTH_IN_BLOCKS;
            UInt32 verticalBlockCt   = FACE_INDEXER_GRID_HEIGHT_IN_BLOCKS;
            
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
                        float range[] = { -0.1, 255.000001 }; // [0, 255]
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
            
            
            CIImage * croppedFace = face.croppedFaceImage;
            CGImageRef faceRef = [ImageUtil renderCIImage:croppedFace];
            UIImage * tempUIImage = [[UIImage alloc] initWithCGImage:faceRef];
            NSData * jpegData = UIImageJPEGRepresentation(tempUIImage, 0.8);
            NSString * faceCropID = [NSString stringWithFormat:@"%@_%@", faceUUID, kCBIRSourceFaceImage];
            [revision setAttachmentNamed:faceCropID withContentType:MIME_TYPE_OCTET_STREAM content:jpegData];
            CGImageRelease(faceRef);
            
            
            // Load up all data.
            faceData[kCBIRFaceRect] = NSStringFromCGRect(face.faceRect);
            faceData[kCBIRFaceID] = faceUUID;
            faceData[kCBIRFeatureIDList] = featureIdentifiers;
            faceData[kCBIRHistogramImage] = faceHistoID;
            faceData[kCBIRSourceFaceImage] = faceCropID;

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
// of the color that the bin represents in the region.  This should correct for equal faces at different scales which cause
// the values of each intensity to be scaled to more or less, despite the images being effectively equal.
- (void) percentizeHistogram:(cv::Mat *)lbpHistogram blockArea:(size_t)area
{
    // Recall that cv::normalize(lbpHistogram, lbpHistogram, 0, block_width * block_height, cv::NORM_MINMAX, -1, cv::Mat() );
    // doesn't do the trick.
    
    cv::Mat col = lbpHistogram->col(0);
    for ( int i = 0; i < col.rows; i++ ) {
        float & valRef = col.at<float>(i);
        valRef /= area;
        valRef *= 100;
        //NSLog(@"valRef is: %f", valRef);
    }
}

- (NSString *) generateFaceKey
{
    return [NSString stringWithFormat:@"%@%@", FACE_KEY_PREFIX, [NSUUID UUID].UUIDString];
}


@end