//
//  DifferenceFilter.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/7/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CoreImage/CoreImage.h>

@interface DifferenceFilter : CIFilter

@property (nonatomic) CIImage * inputImage;

@property (nonatomic, readonly) CIKernel * kernel;

@end
