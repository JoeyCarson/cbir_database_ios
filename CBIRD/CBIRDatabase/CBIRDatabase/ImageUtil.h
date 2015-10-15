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

+ (CGImageRef)renderCIImage:(CIImage *)img;

@end
