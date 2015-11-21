//
//  DoGFilter.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/21/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>


// Implements a Difference of Gaussians Filter by running the same input image through
// a CIGaussianBlur filter using the given radii separately and outputs the difference
// of those two images.
// https://developer.apple.com/library/prerelease/ios/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/CIGaussianBlur
@interface DoGFilter : CIFilter

@property (nonatomic) CIImage * inputImage;
@property (nonatomic, assign) CGFloat rad1;
@property (nonatomic, assign) CGFloat rad2;


@end
