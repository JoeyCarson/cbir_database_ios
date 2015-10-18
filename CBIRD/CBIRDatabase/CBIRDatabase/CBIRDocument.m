//
//  CBIRDocument.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/4/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRDocument.h"


/**
 * Represents a CBIRDocument (a database entity) whose properties and structure
 * can be stored in CouchBase.
 */
@implementation CBIRDocument

@synthesize imageResource = _imageResource;
@synthesize persistentID = _persistentID;
@synthesize persistentIDType = _persistentIDType;

// Initialize the document with the image resource and persistent identifier.
// The CBIRDocument shall take ownership of the given CGImageRef.
-(instancetype)initWithCIImage:(CIImage *)image persistentID:(NSString *)persistentID type:(enum PERSISTANCE_ID_TYPE)persistentIDType
{
    self = [super init];
    if ( self ) {
        self->_imageResource = image;
        self->_persistentID = persistentID;
        self->_persistentIDType = persistentIDType;
    }
    
    return self;
}

-(void)dealloc
{
    if ( _imageResource ) {
        // In cases of memory drain, it might be a good idea to check the retain count on the image resource.
        //NSLog(@"CBIRDocument releasing CGImage with retain count: %ld", CFGetRetainCount(_imageResource));
        //CGImageRelease(_imageResource);
    }
}

@end
