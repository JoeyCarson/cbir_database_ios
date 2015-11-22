//
//  ImageUtil.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/13/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#import <opencv2/opencv.hpp>

#import "ImageUtil.h"

@implementation CIImage(Affine)

// Implement rotation of the image.
- (CIImage *)rotateDegrees:(float)aDegrees
{
    CIImage *im = self;
    if (aDegrees > 0.0 && aDegrees < 360.0)
    {
//        CIFilter *f
//        = [CIFilter filterWithName:@"CIAffineTransform"];
//        NSAffineTransform *t = [NSAffineTransform transform];
//        [t rotateByDegrees:aDegrees];
//        [f setValue:t forKey:@"inputTransform"];
//        [f setValue:im forKey:@"inputImage"];
//        im = [f valueForKey:@"outputImage"];
    }
    return im;
}

-(NSNumber *) getOrientation
{
    NSNumber * orientation = [[self properties] valueForKey:((__bridge NSString *)kCGImagePropertyOrientation)];
    return orientation;
}

@end






@implementation ImageUtil

+ (CGImageRef)renderCIImage:(CIImage *)img
{
    return [ImageUtil renderCIImage:img withContext:nil];
}

+(void)dumpDebugImage:(CIImage *)img
{
    void (^dumpDebugImage)() = ^void(){
        CGImageRef imgRef = [ImageUtil renderCIImage:img];
        UIImage * uiImage = [UIImage imageWithCGImage:imgRef];
        
        NSLog(@"dumping debug image descritptor to Photo Album. TIFF orientation: %@", [img getOrientation]);
        UIImageWriteToSavedPhotosAlbum(uiImage, [ImageUtil class], @selector(image:didFinishSavingWithError:contextInfo:), nil);
    };
    
    // Only use for debugging!!  Beware dumping shit tons of new images into the photo album!!
    dispatch_async(dispatch_get_main_queue(), dumpDebugImage);
}

+(void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSLog(@"debug LBP output face.  error: %@", error);
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

+ (CGFloat)resolveRotationAngle:(CIImage *)image
{
    NSUInteger tiffOrientation = TIFF_TOP_LEFT;
    NSNumber * orientationNum = [image getOrientation];
    if ( orientationNum ) {
        tiffOrientation = [orientationNum integerValue];
    }
    
    NSAssert(tiffOrientation >= 1 && tiffOrientation <= 6, @"Fatal: TIFF orientation invalid.");
    
    // Angles are anti-clockwise.
    CGFloat rotationDeg;
    
    switch (tiffOrientation)
    {
        // 1 = The 0th row represents the visual top of the image, and the 0th column represents the visual left-hand side.
        // This means (0, 0) is at the bottom left.  Normal CI coordinate system.  No change.
        //     t
        // l |---
        //   |
        case TIFF_TOP_LEFT:
            rotationDeg = 0;
            break;
            
        // 2 = The 0th row represents the visual top of the image, and the 0th column represents the visual right-hand side.
        // Top Left Mirrored about y-axis.  Effectively the angle of the front camera.
        // This means (0, 0) is at the bottom left.  Normal CI coordinate system.  No change.
        //     t
        // r |---
        //   |
        case TIFF_TOP_RIGHT:
            rotationDeg = 0;
            break;
            

        // 3 = The 0th row represents the visual bottom of the image, and the 0th column represents the visual right-hand side.
        // This means (0, 0) is at the top right.
        //     b
        // r |---
        //   |
        case TIFF_BOTTOM_RIGHT:
            rotationDeg = -180;
            break;
            
        // 4 = The 0th row represents the visual bottom of the image, and the 0th column represents the visual left-hand side.
        // This means (0, 0) is actually at the top left.
        //     b
        // l |---
        //   |
        case TIFF_BOTTOM_LEFT:
            rotationDeg = -180;
            break;
            
        // 5 = The 0th row represents the visual left-hand side of the image, and the 0th column represents the visual top.
        // This means
        //     l
        // t |---
        //   |
        case TIFF_LEFT_TOP:
            rotationDeg = -90;
            break;
            
        // 6 = The 0th row represents the visual right-hand side of the image, and the 0th column represents the visual top.
        //     r
        // t |---
        //   |
        case TIFF_RIGHT_TOP:
            rotationDeg = -90;
            break;

        // 7 = The 0th row represents the visual right-hand side of the image, and the 0th column represents the visual bottom.
        //     r
        // b |---
        //   |
        case TIFF_RIGHT_BOTTOM:
            rotationDeg = 90;
            break;
        
        // 8 = The 0th row represents the visual left-hand side of the image, and the 0th column represents the visual bottom.
        //     l
        // b |---
        //   |
        case TIFF_LEFT_BOTTOM:
            rotationDeg = 90;
            break;
            
        default: rotationDeg = 0;
    }
    
    
    
    return 0;
}


@end
