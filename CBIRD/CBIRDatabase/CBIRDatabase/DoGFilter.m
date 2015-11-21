//
//  DoGFilter.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/21/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "DoGFilter.h"

// In imaging science, difference of Gaussians is a feature enhancement algorithm that involves the subtraction of one blurred
// version of an original image from another, less blurred version of the original. DoG(I) = I(r1) - I(r2), such that r2 > r1.
// https://en.wikipedia.org/wiki/Difference_of_Gaussians
static NSString * const kernelCode =@"                                                                             \n"
                                     "                                                                             \n"
                                     "                                                                             \n"
                                     "                                                                             \n"
                                     "                                                                             \n"
                                     "kernel vec4 diff ( sampler b1, sampler b2 )                                  \n"
                                     "{                                                                            \n"
                                     "    vec4 b1C = sample(b1, samplerCoord(b1));                                 \n"
                                     "    vec4 b2C = sample(b2, samplerCoord(b2));                                 \n"
                                     "                                                                             \n"
                                     "                                                                             \n"
                                     "    return  b1C - b2C;                                                       \n"
                                     "}                                                                            \n";



@implementation DoGFilter
{
    CIFilter * m_guassianBlurFilter;
    CIKernel * m_differenceKernel;
}

@synthesize inputImage = _inputImage;
@synthesize rad1 = _rad1;
@synthesize rad2 = _rad2;

-(instancetype)init
{
    self = [super init];
    if ( self ) {
        // TODO: lazy instantiate.
        m_guassianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
        m_differenceKernel = [CIKernel kernelWithString:kernelCode];
        self.rad1 = 1;
        self.rad2 = 2;
    }
    
    return self;
}

-(CIImage *)outputImage
{
    // See DoG explanation above kernel program.
    NSAssert(self.rad1 > 0 && self.rad2 > 0 && self.rad2 > self.rad1, @"DoGFilter radii must be greater than zero and rad2 must be greater than rad1.");
    
    // Use the same input image both times.
    [m_guassianBlurFilter setValue:self.inputImage forKey:@"inputImage"];
    
    // Configure the first blurred image.
    NSNumber * rad1Number = [NSNumber numberWithDouble:self.rad1];
    [m_guassianBlurFilter setValue:rad1Number forKey:@"inputRadius"];
    CIImage * blur1 = m_guassianBlurFilter.outputImage;
    
    // Configure the second blurred image.
    NSNumber * rad2Number = [NSNumber numberWithDouble:self.rad2];
    [m_guassianBlurFilter setValue:rad2Number forKey:@"inputRadius"];
    CIImage * blur2 = m_guassianBlurFilter.outputImage;
    
    // Now diff them using the kernel.
    CIKernelROICallback roi = ^CGRect (int index, CGRect destRect) {
        if ( CGRectIsInfinite(destRect) ) {
            return CGRectNull;
        }
        else return destRect;
    };
    
    CIImage * DoG = [m_differenceKernel applyWithExtent:self.inputImage.extent roiCallback:roi arguments:@[blur1, blur2]];
    return DoG;
}



@end
