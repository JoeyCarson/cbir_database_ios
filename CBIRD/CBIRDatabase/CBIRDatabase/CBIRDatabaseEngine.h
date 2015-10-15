//
//  CBIRDatabaseEngine.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>


@class CBIRIndexer;
@class CBIRDocument;
@class CBIRIndexResult;

@interface CBIRDatabaseEngine : NSObject

+(instancetype) sharedEngine;

// Index in all available images.
-(CBIRIndexResult *)indexImage:(CBIRDocument *)imgDoc;

// Register the indexer object according to its name.
-(void)registerIndexer:(CBIRIndexer *)indexer;

@end
