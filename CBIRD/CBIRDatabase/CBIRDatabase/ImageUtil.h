//
//  ImageUtil.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/13/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CIImage;

@interface ImageUtil : NSObject

// Renders a CIImage to a CGImageRef.  The caller is responsible for
// releasing the CGImageRef when it's no longer necessary.
+ (CGImageRef)renderCIImage:(CIImage *)img;

// Renders a CIImage to given context.
+ (CGImageRef)renderCIImage:(CIImage *)img withContext:(CIContext *)ctx;

// Utilizes Apple's face detection API to return rectangles that should
// contain faces.
+ (NSArray *) detectFaces:(CIImage *)img;

// Utilizes Apple's face detection API to return rectangles that should
// contain faces.  Pass any options to override the default face detection options.
+ (NSArray *) detectFaces:(CIImage *)img overrideOpts:(NSDictionary *)overrideOpts;

// Wrapper for copyPixelData passing a nil context, which causes the usage
// of a default context.  Call the other copyPixelData if you require a defined
// context.
+ (NSData *) copyPixelData:(CIImage *)image;

// Copies the pixel data buffer from the rendered CIImage and transfers
// ownership to ARC.  Cleans up the rendered CGImageRef memory as well.
+ (NSData *) copyPixelData:(CIImage *)image withContext:(CIContext *)ctx;

+ (void) dumpDebugImage:(CIImage *)img;

+(NSData *)copyPixelDataFromCGImage:(CGImageRef)renderedCGImage;

// Utility function for extracting block features from the given pixel data object.
// [1 ][2 ][3 ][4 ][5 ]
// [6 ][7 ][8 ][9 ][10]
// [11][12][13][14][15]
//
// Extracts the block rectangle according to the given rectangle from the given data object into the given buffer.
// The widths of the given rect and size should account for the number of bytes per pixel.
// TODO: This sucks.  Come up with a more convenient implementation that doesn't require the caller to specify count of bytes
//       per pixel, either by making it a parameter or interpreting it inside the function when given an image.
// @param blockRect - CGRect that specifies the block index and size.  The origin of the rectangle is interpreted to mean
//                    the row index and block in the row to return, such that all blocks are considered to be the same size.
//                    It's the caller's responsibility to ensure that they're safely indexing into the data object.
// @param pixelData - The NSData object to read from.
// @param size      - The size of the NSData object.
// @param buffer    - The output buffer used to write into.
+ (void) extractRect:(CGRect)blockRect fromData:(NSData *)pixelData ofSize:(CGSize)size intoBuffer:(unsigned char *)buffer;




@end
