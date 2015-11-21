//
//  ImageUtil.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/13/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#import <opencv2/opencv.hpp>

#import "ImageUtil.h"

@implementation ImageUtil

+ (CGImageRef)renderCIImage:(CIImage *)img
{
    return [ImageUtil renderCIImage:img withContext:nil];
}

+ (CGImageRef)renderCIImage:(CIImage *)img withContext:(CIContext *)ctx
{
    if ( !ctx ) {
        NSDictionary * options = @{kCIContextOutputColorSpace:[NSNull null], kCIContextWorkingColorSpace:[NSNull null]};
        ctx = [CIContext contextWithOptions:options];
    }
    
    return [ctx createCGImage:img fromRect:img.extent];
}

+ (NSArray *) detectFaces:(CIImage *)img
{
    return [ImageUtil detectFaces:img overrideOpts:nil];
}

+ (NSArray *) detectFaces:(CIImage *)img overrideOpts:(NSDictionary *)overrideOpts
{
    static CIContext * ctx = [CIContext contextWithOptions:nil];
    NSMutableDictionary<NSString *, id> * options = [NSMutableDictionary new];
    options[CIDetectorAccuracy] = CIDetectorAccuracyHigh;
    
    NSNumber * orientation = [[img properties] valueForKey:((__bridge NSString *)kCGImagePropertyOrientation)];
    if ( orientation ) {
        options[CIDetectorImageOrientation] = orientation;
    }
    
    // Use override orientation if it's given.
    if ( overrideOpts[CIDetectorImageOrientation] ) {
        options[CIDetectorImageOrientation] = overrideOpts[CIDetectorImageOrientation];
    }
    
    
    
    NSArray * faces = nil;
    CIDetector * detector = [CIDetector detectorOfType:CIDetectorTypeFace context:ctx options:options];
    faces = [detector featuresInImage:img options:options];

    NSLog(@"detectFaces.  %@", faces);
    return faces;
}

+ (NSData *) copyPixelData:(CIImage *)image
{
    return [ImageUtil copyPixelData:image withContext:nil];
}

+ (NSData *) copyPixelData:(CIImage *)image withContext:(CIContext *)ctx
{
    NSData * pixelData = nil;
    
    if( image ) {
        CGImageRef renderedCGImage = [ImageUtil renderCIImage:image withContext:ctx];
        pixelData = [ImageUtil copyPixelDataFromCGImage:renderedCGImage];
        CGImageRelease(renderedCGImage);
    }
    
    return pixelData;
}

+(NSData *)copyPixelDataFromCGImage:(CGImageRef)renderedCGImage
{
    CFDataRef cfData = CGDataProviderCopyData( CGImageGetDataProvider(renderedCGImage) );
    NSData * pixelData = nil;
    
    if ( cfData ) {
        pixelData = (__bridge_transfer NSData *)cfData;
    }
    
    return pixelData;
}

+ (void) extractRect:(CGRect)blockRect fromData:(NSData *)pixelData ofSize:(CGSize)size intoBuffer:(unsigned char *)buffer
{
    // Total image width and height.
    UInt32 width = size.width;
    UInt32 height = size.height;
    
    UInt32 block = blockRect.origin.x;
    UInt32 blockRow = blockRect.origin.y;
    UInt32 blockWidth = blockRect.size.width;
    UInt32 blockHeight = blockRect.size.height;
    
    // Clear the block memory.
    memset(buffer, 0, sizeof(*buffer));
    
    // Determine how many times and how many bytes we should memcpy to stay within image bounds.
    UInt32 local_block_width  = ((block + 1) * blockWidth > width) ? ( width - (block * blockWidth) ) : blockWidth;
    UInt32 local_block_height = ((blockRow + 1) * blockHeight > height) ? ( height - (blockRow * blockHeight) ) : blockHeight;
    
    const unsigned char * pBlockBegin = ((const unsigned char *)pixelData.bytes) + (blockRow * width * blockHeight) + (block * blockWidth);
    const unsigned char * pInput = pBlockBegin;
    
    for ( UInt32 local_row = 0; local_row < local_block_height; local_row++ ) {
        memcpy(buffer, pInput, local_block_width);
        buffer += blockWidth;
        pInput += width;
    }
}




@end
