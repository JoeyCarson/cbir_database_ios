//
//  ChiSquareFilter.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/7/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>

@interface ChiSquareFilter : CIFilter

// The expected image resource.  Typically the input image when searching.
@property (nonatomic) CIImage * expectedImage;

// The training image.  The image from the training set.
@property (nonatomic) CIImage * trainingImage;

@property (nonatomic, assign) short binCount;

// The kernel used to compute the absolute squared difference ratio
// between the expected and training images.
@property (nonatomic, readonly) CIKernel * absSquareDiffExpectedRatioKernel;

// The kernel used to compute the histo sum output.
@property (nonatomic, readonly) CIKernel * histoSumKernel;

@end
