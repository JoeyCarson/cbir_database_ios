//
//  HistogramDifferenceFilter.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/7/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "DifferenceFilter.h"

static NSString * const kernelCode = @"                                       \n"
"                                                                             \n"
"                                                                             \n"
"                                                                             \n"
"                                                                             \n"
"kernel vec4 histogramDiff ( sampler i )                                      \n"
"{                                                                            \n"
"                                                                             \n"
"                                                                             \n"
"    // Output pixels are [0.0, 1.0]                                          \n"
"    return vec4(1.0, 0.0, 0.0, 1.0);                                         \n"
"}                                                                            \n";

@implementation DifferenceFilter

@synthesize inputImage = _inputImage;

@end
