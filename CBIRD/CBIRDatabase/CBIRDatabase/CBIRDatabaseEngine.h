//
//  CBIRDatabaseEngine.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@class CBIRQuery;
@class CBIRIndexer;
@class CBIRDocument;
@class CBIRIndexResult;
@class CBLDocument;

@interface CBIRDatabaseEngine : NSObject

// Whether or not the database engine thread is running.
@property (nonatomic, readonly, getter=isRunning) BOOL running;

// Whether or not the database engine thread has been terminated.
@property (nonatomic, readonly, getter=isTerminated) BOOL terminated;

// Retrieve a pointer to the shared engine.
+(instancetype) sharedEngine;

// Shutdown the database engine.  Calling this method
// destroys the shared engine instance, terminating the
// database engine thread and making the instance useless.
// Returns true only when the database engine is actually
// shutdown.  If called subsequently, false will be returned.
+(BOOL) shutdown;

// Index in all available images.
-(CBIRIndexResult *)indexImage:(CBIRDocument *)imgDoc;

// Register the indexer object according to its name.
-(void)registerIndexer:(CBIRIndexer *)indexer;

-(CBLDocument *)getDocument:(NSString *)persistentID;


// Asynchronously runs the given CBIRQuery object.  CBIRQuery shall provide asynchronous callback mechanisms.
-(void)execQuery:(CBIRQuery *)query;

@end
