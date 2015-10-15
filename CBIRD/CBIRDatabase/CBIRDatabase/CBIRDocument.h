//
//  CBIRDocument.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/4/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>


enum PERSISTANCE_ID_TYPE {
    UNKNOWN,
    PH_ASSET
};

@interface CBIRDocument : NSObject

/**
 * The image resource associated with the CBIRDocument.
 */
@property (nonatomic, readonly) CGImageRef imageResource;

/**
 * The unique identifier of the CBIRDocument object.
 */
@property (nonatomic, readonly, copy) NSString * persistentID;


@property (nonatomic, readonly) enum PERSISTANCE_ID_TYPE persistentIDType;


-(instancetype)initWithCGImage:(CGImageRef)image persistentID:(NSString *)persistentID type:(enum PERSISTANCE_ID_TYPE)persistentIDType;

@end
