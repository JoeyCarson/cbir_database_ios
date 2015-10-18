//
//  ImageUtil.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/13/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#import "ImageUtil.h"


@implementation ImageUtil

+ (CGImageRef)renderCIImage:(CIImage *)img
{
    CIContext * ctx = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ctx createCGImage:img fromRect:img.extent];
    NSLog(@"ImageUtil CGImage retain count: %ld", CFGetRetainCount(cgImage));
    return cgImage;
}

+ (NSArray *) detectFaces:(CIImage *)img
{
    CIContext * ctx = [CIContext contextWithOptions:nil];
    NSDictionary<NSString *, id> * options = @{CIDetectorAccuracy: CIDetectorAccuracyHigh};
    
    CIDetector * detector = [CIDetector detectorOfType:CIDetectorTypeFace context:ctx options:options];
    
    NSNumber * orientation = [[img properties] valueForKey:((__bridge NSString *)kCGImagePropertyOrientation)];
    if ( orientation ) {
        options = @{CIDetectorImageOrientation : orientation};
    }
    
    return [detector featuresInImage:img options:options];
}

@end
