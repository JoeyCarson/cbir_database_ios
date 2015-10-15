//
//  FaceIndexer.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/15/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>

#import "CBIRDocument.h"
#import "LBPFilter.h"
#import "FaceIndexer.h"
#import "ImageUtil.h"

@implementation FaceIndexer

-(CBIRIndexResult *)indexImage:(CBIRDocument *)document
{
    // 1.  Filter the image using the LBP filter.
    CIImage * filteredImage = [self generateFilteredImage:document.imageResource];
    
    // 2.  Generate the index by computing and stringing histograms.
    CGImageRef imageRef = [ImageUtil renderCIImage:filteredImage];
    CGImageRelease(imageRef);
    
    // 3.  Return the result with a preview of the filtered image for the UI to use for funzies.
    UIImage * i = [UIImage imageWithCIImage:filteredImage scale:1.0 orientation:UIImageOrientationUp];
    CBIRIndexResult * result = [[CBIRIndexResult alloc] initWithResult:YES filteredImage:i];
    return result;
}


-(CIImage *) generateFilteredImage:(CGImageRef)imgRef
{
    // First hand the image to the a CIImage instance so that we can input it into the filter.
    CIImage * image = [[CIImage alloc] initWithCGImage: imgRef];
    
    NSLog(@"generateFilteredImage: after %ld", CFGetRetainCount(imgRef));
    
    // Instantiate the filter and set the input image to the instance we just created.
    LBPFilter * lbpf = [[LBPFilter alloc] init];
    lbpf.inputImage = image;
    
    // Generate the output image from the filter.
    image = lbpf.outputImage;
    
    return image;
}

@end
