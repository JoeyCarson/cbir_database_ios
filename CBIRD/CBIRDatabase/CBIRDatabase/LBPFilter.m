//
//  LBPFilter.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/4/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "LBPFilter.h"

#define kCIColorMonochromeFilterName @"CIColorMonochrome"

@interface NSValue(CGRect)

+(instancetype)valueWithRect:(CGRect)r;
-(CGRect) rectValue;

@end

@implementation NSValue(CGRect)

+(instancetype)valueWithRect:(CGRect)rect
{
    return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
}

-(CGRect) rectValue
{
    CGRect rect;
    [self getValue:&rect];
    return rect;
}

@end


//static NSString * kernelCode = @"kernel vec4       doNothing ( __sample s ) { return s.rgba; }";

// Local Binary Patterns (Naive Implementation).
// This implementation starts at the top right pixel and moves around clockwise, computing
// the local binary pattern.  The input image is expected to be in grayscale already, e.g.
// monochrome white (each pixel is equal).  http://www.bytefish.de/blog/local_binary_patterns
//
// Pixel Layout: cc is destCoord().  The rest are pixel values.
// [tl = top left   ]  [tc = top center   ] [tr = top right   ]
// [cl = center left]  [cc = destCoord()  ] [cr = center right]
// [bl = bottom left]  [bc = bottom center] [br = bottom right]
//
//  Output pixel format is binary digit for each pixel in the following layout.
//  [tl tc tr bl bc br cl cr]
//  [7  6  5  4  3  2  1  0 ]
NSString *kernelCode =       @"                                                                             \n"
                              "// Returns 1 if the color at p in the given image is greater than or         \n"
                              "// equal to the given color, and zero otherwise.                             \n"
                              "int binColor(sampler img, vec2 p, vec4 cC) {                                 \n"
                              "    vec4 pC = sample(img, samplerTransform(img, p));                         \n"
                              "                                                                             \n"
                              "    // Compare the color vectors according to their magnitudes.              \n"
                              "    // There are probably more visually accurate comparisons.                \n"
                              "    float pCN = sqrt( (pC.r * pC.r) + (pC.g * pC.g) + (pC.b * pC.b) );       \n"
                              "    float cCN = sqrt( (cC.r * cC.r) + (cC.g * cC.g) + (cC.b * cC.b) );       \n"
                              "                                                                             \n"
                              "                                                                             \n"
                              "                                                                             \n"
                              "    if ( pCN >= cCN ) return 1;                                              \n"
                              "    else return 0;                                                           \n"
                              "}                                                                            \n"
                              "                                                                             \n"
                              "                                                                             \n"
                              "                                                                             \n"
                              "                                                                             \n"
                              "kernel vec4 lbp ( sampler i )                                                \n"
                              "{                                                                            \n"
                              "    vec2 c  = destCoord();                                                   \n"
                              "    vec4 cC = sample(i, samplerTransform(i, c));                             \n"
                              "                                                                             \n"
                              "    vec2 tl = c + vec2(-1, 1);                                               \n"
                              "    vec2 tc = c + vec2(0, 1);                                                \n"
                              "    vec2 tr = c + vec2(1, 1);                                                \n"
                              "                                                                             \n"
                              "    vec2 cl = c + vec2(-1, 0);                                               \n"
                              "    vec2 cr = c + vec2(1, 0);                                                \n"
                              "                                                                             \n"
                              "    vec2 bl = c + vec2(-1, -1);                                              \n"
                              "    vec2 bc = c + vec2(0, -1);                                               \n"
                              "    vec2 br = c + vec2(1, -1);                                               \n"
                              "                                                                             \n"
                              "    int binPix = 0;                                                          \n"
                              "                                                                             \n"
                              "    // iOS kernel language doesn't support bit shifting and proper           \n"
                              "    // OR operations.  Instead use the constant values of bit shifts.        \n"
                              "    binPix += (binColor(i, tl, cC) * 128);  // 2^7 = 128                     \n"
                              "    binPix += (binColor(i, tc, cC) * 64);   // 2^6 = 64                      \n"
                              "    binPix += (binColor(i, tr, cC) * 32);   // 2^5 = 32                      \n"
                              "    binPix += (binColor(i, bl, cC) * 16);   // 2^4 = 16                      \n"
                              "    binPix += (binColor(i, bc, cC) * 8);    // 2^3 = 8                       \n"
                              "    binPix += (binColor(i, br, cC) * 4);    // 2^2 = 4                       \n"
                              "    binPix += (binColor(i, cl, cC) * 2);    // 2^1 = 2                       \n"
                              "    binPix += (binColor(i, cr, cC) * 1);    // 2^0 = 1                       \n"
                              "                                                                             \n"
                              "    // Output pixels are [0.0, 1.0]                                          \n"
                              "    float fc = float(binPix) / 255.0;                                        \n"
                              "    return vec4(fc, fc, fc, 1.0);                                            \n"
                              "}                                                                            \n";



// The working standard do almost nothing kernel.
NSString * kern = @" kernel vec4 moveUpTwoPixels (sampler image) {"
"    vec2 dc = destCoord();"
"    vec2 offset = vec2(0.0, 2.0);"
"    return sample (image, samplerTransform (image, dc + offset));"
"}";

@implementation LBPFilter
{
    NSMutableArray * _rectanglesToApply;
}

@synthesize inputImage = _inputImage;
@synthesize kernel = _kernel;

- (instancetype) init
{
    self = [super init];
    if ( self ) {
        _rectanglesToApply = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (CIKernel *)kernel
{
    if ( !_kernel ) {
        _kernel = [CIKernel kernelWithString:kernelCode];
    }
    
    return _kernel;
}

- (void)setDefaults
{
    NSLog(@"%s", __FUNCTION__);
}

-(void)applyToExtent:(CGRect)extent
{
    [_rectanglesToApply addObject:[NSValue valueWithRect:extent]];
}

- (void)setInputImage:(CIImage *)inputImage
{
    NSLog(@"%s Setting input image to %@", __FUNCTION__, inputImage);
    _inputImage = inputImage;
}

- (CIImage *)outputImage
{
    CIKernelROICallback roi = ^CGRect (int index, CGRect destRect) {
        if ( CGRectIsInfinite(destRect) ) {
            return CGRectNull;
        }
        else return destRect;
    };
    
    // TODO: It would be super smart to make a multiple extent base type of CIFilter, to
    // make a filter that applies filters.  But for now, let it be.
    CIImage * returnImage = nil;
    if ( _rectanglesToApply.count > 0 ) {
        for ( NSUInteger i = 0; i < _rectanglesToApply.count; i++ ) {
            NSValue * rectValue = _rectanglesToApply[i];
            returnImage = [self.kernel applyWithExtent:rectValue.rectValue roiCallback:[roi copy] arguments:@[self.inputImage]];
        }
    } else {
        returnImage = [self.kernel applyWithExtent:self.inputImage.extent roiCallback:[roi copy] arguments:@[self.inputImage]];
    }
    
    return returnImage;
}

@end
