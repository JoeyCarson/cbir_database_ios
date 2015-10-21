//
//  CBIRIndexer.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBLDocument, CBIRDocument, UIImage;


@interface CBIRIndexResult : NSObject

@property (nonatomic, readonly) UIImage * filteredImage;

@property (nonatomic, readonly) BOOL indexResult;

-(instancetype)initWithResult:(BOOL)result filteredImage:(UIImage *)image;

@end



@interface CBIRIndexer : NSObject

-(CBIRIndexResult *)indexImage:(CBIRDocument *)document cblDocument:(CBLDocument *)cblDoc;

@end
