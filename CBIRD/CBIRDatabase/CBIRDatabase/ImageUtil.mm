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
    NSMutableDictionary * options = [[NSMutableDictionary alloc] init];
    
    CIContext * ctx = [CIContext contextWithOptions:options];
    
    CGImageRef cgImage = [ctx createCGImage:img fromRect:img.extent ]; // format:kCIFormatRG8 colorSpace:cs

    return cgImage;
}

+ (NSArray *) detectFaces:(CIImage *)img
{
    static CIContext * ctx = [CIContext contextWithOptions:nil];
    NSDictionary<NSString *, id> * options = @{CIDetectorAccuracy: CIDetectorAccuracyHigh};
    
    CIDetector * detector = [CIDetector detectorOfType:CIDetectorTypeFace context:ctx options:options];
    
    NSNumber * orientation = [[img properties] valueForKey:((__bridge NSString *)kCGImagePropertyOrientation)];
    if ( orientation ) {
        options = @{CIDetectorImageOrientation : orientation};
    }
    
    NSLog(@"before detection.");
    NSArray * faces = nil;
    
    NSArray * tempf = [detector featuresInImage:img options:options];
    faces = tempf;

    NSLog(@"after detection.  %@", faces);
    return faces;
}

+ (NSData *) copyPixelData:(CIImage *)image
{
    NSData * pixelData = nil;
    
    if( image ) {
        CGImageRef renderedCGImage = [ImageUtil renderCIImage:image];
        CFDataRef cfData = CGDataProviderCopyData( CGImageGetDataProvider(renderedCGImage) );
        
        CGImageRelease(renderedCGImage);
        
        if ( cfData ) {
            pixelData = (__bridge_transfer NSData *)cfData;
        }
        
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
