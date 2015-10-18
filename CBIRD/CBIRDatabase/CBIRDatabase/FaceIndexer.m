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
    NSArray<CIImage *> * filteredImages = [self generateFilteredImages:document.imageResource];
    
    // 2.  Generate the index by computing and stringing histograms.
//    CGImageRef imageRef = [ImageUtil renderCIImage:filteredImage];
//    CGImageRelease(imageRef);
    
    // 3.  Return the result with a preview of the filtered image for the UI to use for funzies.
    UIImage * i = [UIImage imageWithCIImage:(filteredImages.count ? filteredImages[0] : nil) scale:1.0 orientation:UIImageOrientationUp];
    CBIRIndexResult * result = [[CBIRIndexResult alloc] initWithResult:YES filteredImage:i];
    return result;
}


-(NSArray<CIImage *> *) generateFilteredImages:(CIImage *)image
{
    NSMutableArray * lbpFaceImages = [[NSMutableArray alloc] init];
    
    // Instantiate the filter and set the input image to the instance we just created.
    LBPFilter * lbpf = [[LBPFilter alloc] init];
    lbpf.inputImage = image;
    
    // Apply the LBP filter only to face rectangles in the image, or the whole thing if none are there.
    NSArray * faceFeatures = [ImageUtil detectFaces:image];
    for ( CIFaceFeature * feature in faceFeatures ) {
        [lbpf applyToExtent:feature.bounds];
        [lbpFaceImages addObject:lbpf.outputImage];
    }
    
    return lbpFaceImages;
}

@end
