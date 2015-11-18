//
//  ChiSquareFilter.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/7/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "ChiSquareFilter.h"


// The ChiSquareFilter class implements a Chi-Square histogram difference algorithm
// that can be parallelized over the GPU using custom CIKernels.
// The algorithm is a parallel implementation of the ChiSquare difference algorithm of OpenCV.
// http://docs.opencv.org/2.4/doc/tutorials/imgproc/histograms/histogram_comparison/histogram_comparison.html
//
// It's parallleized over the GPU by using two CIKernels, that do the following.
// 1. Computes the absolute squared difference to expected value ratio.
// 2. A summation of of the histogram differences over across the histogram bin range.
//
// The expected value is the histogram image that you want to match against.  The training image
// should be considered the histogram image from a training set.  Both images must be compatible
// with one another (equal in block dimensions and number of bins per block).
//
// The spatial layout of the memory histogram image is as follows.
// [0][1]   for a 2x2 histogram image. memory buffer: [0][1][2][3].
// [2][3]                              where each [] is the histogram of floats, each n bins.
//
// However, note that the CoreImage coordinate space is (0, 0) at bottom left corner.
// This means that in the kernel, it will be operating the space as follows.
// [2][3]
// [0][1]
//
// This is perfectly fine as the kernel only operates on the x parameter which maintains the same change
// pattern as the how the data is structured.
//
//
// Since each histogram image is equal in bins, data type size, and block dimensions, they are easily parallelizable on
// the graphics hardware.  Each value is independent of one another, so as long as we understand the dimensions of each
// histogram and stay within their respective regions, we can easily parallelize the computation. Sweet deal.
//
//
// Kernel algorithms.
// Absolute square difference to expected ratio kernel.
// ((expectHisto[i] - trainingHisto[i])^2) / expectHisto[i].
//
// Histogram summation kernel.
// The previous kernel was simpler because it didn't have to be cognizant of region space.
// The summation filter has to ensure that it's only summing across the range of the current
// histogram bins.  It must determine that it's looking at the first bin in a histogram and
// if so return the output as the summation of it and rest of the bins in the range of the
// histogram.  Zero (0) should be output for the rest of the pixels in the histogram.
//
// So the algorthm looks like.
// if ( destCoord().x % binCount == 0 )
//    end = destCoord.x + binCount;
//    for ( x = destCoord.x; x < end; x++ )
//

static NSString * const absSquareDiffCode = @"                                                                            \n"
                                            "                                                                             \n"
                                            "                                                                             \n"
                                            "                                                                             \n"
                                            "                                                                             \n"
                                            "kernel vec4 histogramDiff ( sampler expect )               \n"
                                            "{                                                                            \n"
                                            "                                                                             \n"
                                            "    // , sampler training                                                                         \n"
                                            "    // Recall that we're only concerned with the red component.              \n"
                                            "    //float expIntensity = samplerCoord(expect).r;                             \n"
                                            "    //float trainIntensity = samplerCoord(training).r;                         \n"
                                            "                                                                             \n"
                                            "    //float diff = expIntensity - trainIntensity;                              \n"
                                            "    //float diffSquare = diff * diff;                                          \n"
                                            "    //float diffSquareExpRatio = diffSquare / expIntensity;                    \n"
                                            "                                                                             \n"
                                            "    //return vec4(expIntensity, 0, 0, 1);  //diffSquareExpRatio              \n"
                                            "    return sample(expect, samplerCoord(expect));                             \n"
                                            "}                                                                            \n";

static NSString * const summationCode = @"                                                                            \n"
                                        "                                                                             \n"
                                        "                                                                             \n"
                                        "                                                                             \n"
                                        "// We need range too!                                                        \n"
                                        "kernel vec4 histogramDiff ( sampler s  )                                     \n"
                                        "{                                                                            \n"
                                        "                                                                             \n"
                                        "     int binCount = %d                                                       \n"
                                        "                                                                             \n"
                                        "                                                                             \n"
                                        "}                                                                            \n";



@implementation ChiSquareFilter


@synthesize expectedImage = _expectedImage;
@synthesize trainingImage = _trainingImage;
@synthesize absSquareDiffExpectedRatioKernel = _absSquareDiffExpectedRatioKernel;
@synthesize histoSumKernel = _histoSumKernel;
@synthesize binCount = _binCount;


-(instancetype)init
{
    self = [super init];
    if ( self ) {
        
    }
    
    return self;
}

-(void)setBinCount:(short)binCount
{
    if ( binCount != _binCount ) {
        // The bin counts are different, meaning that we must
        // rebuild histogram sum kernel.
        _binCount = binCount;
        _histoSumKernel = nil;
    }
}

-(CIKernel *)absSquareDiffExpectedRatioKernel
{
    if ( !_absSquareDiffExpectedRatioKernel ) {
        NSLog(@"generating absolute square difference to expected value ratio kernel.");
        _absSquareDiffExpectedRatioKernel = [CIKernel kernelWithString:absSquareDiffCode];
    }
    
    return _absSquareDiffExpectedRatioKernel;
}

-(CIKernel *)histoSumKernel
{
    if ( !_histoSumKernel ) {
        NSLog(@"");
        NSString * summationKernelCode = [NSString stringWithFormat:summationCode, self.binCount];
        NSLog(@"summationKernelCode: %@", summationKernelCode);
        _histoSumKernel = [CIKernel kernelWithString:summationKernelCode];
    }
    
    return _histoSumKernel;
}

-(CIImage *)outputImage
{
    // TODO: Get your ass in gear on setting the roi callbacks.
    CIKernelROICallback roi = ^CGRect (int index, CGRect destRect) {
        if ( CGRectIsInfinite(destRect) ) {
            return CGRectNull;
        }
        else return destRect;
    };
    
    
    CIImage * absSquareRatioImage = [self.absSquareDiffExpectedRatioKernel applyWithExtent:self.expectedImage.extent
                                                                          roiCallback:roi
                                                                            arguments:@[self.expectedImage/*, self.trainingImage*/]];
    
    
//    CIImage * histoSum = [self.histoSumKernel applyWithExtent:absSquareRatioImage.extent
//                                                  roiCallback:roi
//                                                    arguments:@[absSquareRatioImage]];
    
    
    
    // This isn't it.  We still need to apply the other.
    return absSquareRatioImage;
}














@end
