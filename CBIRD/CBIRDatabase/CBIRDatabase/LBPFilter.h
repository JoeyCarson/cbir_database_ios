//
//  LBPFilter.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/4/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>

/**
 * Filter that computes and outputs a Local Binary Patterns image.
 */
@interface LBPFilter : CIFilter

@property (nonatomic) CIImage * inputImage;

@property (nonatomic, readonly) CIKernel * kernel;

// Adds the rect to a list of rectangles to be applied to during outputImage.
// If no extents are given, then the the LBP filter is applied to the entire image rectangle.
-(void)applyToExtent:(CGRect)extent;

@end
