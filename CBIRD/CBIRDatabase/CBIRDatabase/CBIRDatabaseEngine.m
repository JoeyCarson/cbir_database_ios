//
//  CBIRDatabaseEngine.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CBIRDatabaseEngine.h"
#import "CBIRDocument.h"
#import "CBIRIndexer.h"
#import "FaceIndexer.h"

#import <CouchbaseLite/CouchbaseLite.h>

#define CBIRD_ENGINE_QUEUE_NAME "cbird_db_engine_queue"
#define CBIR_IMAGE_DB_NAME @"cbird_image_db"

@interface CBIRDatabaseEngine(Private)

-(instancetype)initPrivate;

-(CBLDatabase *)databaseForName:(NSString *)name;

@end

CBIRDatabaseEngine * _singletonEngine;

@implementation CBIRDatabaseEngine
{
    // All registered indexers.
    NSMutableDictionary * m_indexers;

    // One serial dispatch queue for all transactions.
    NSOperationQueue * m_engQueue;
    
    // Manager for CBL.  Don't use sharedInstance as
    // it's only recommended to be used on the main thread.
    CBLManager * m_cblManager;
}

/**
 * Designated Initializer is NOT supported.
 */
-(instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

-(instancetype)initPrivate
{
    self = [super init];

    if ( self ) {
        NSLog(@"initPrivate!!");
        // Create the serial dispatch queue.  It seems plausible that the underlying queue is released during dealloc.
        dispatch_queue_t eng_queue = dispatch_queue_create(CBIRD_ENGINE_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
        m_engQueue = [[NSOperationQueue alloc] init];
        m_engQueue.underlyingQueue = eng_queue;
        
        // Initialize indexer list.
        __block BOOL success = NO;

        // Create the CBLManager on the engine queue.
        void (^initCBLBlock)(void) = ^void(void) {
            NSError * error = nil;
            m_cblManager = [[CBLManager alloc] initWithDirectory:CBLManager.defaultDirectory options:nil error:&error];
            
            if ( error ) {
                NSLog(@"CBIRDatabaseEngine: CBLManager instantiation failure: %@", error);
            } else {
                // Add all built in supported indexers.
                [self initBuiltinIndexers];
                
                // Trash the database to help with debugging in early stages of development.
                [self deleteDatabaseNamed:CBIR_IMAGE_DB_NAME];
                success = YES;
            }
        };
        
        NSBlockOperation * blockOp = [NSBlockOperation blockOperationWithBlock:initCBLBlock];
        [m_engQueue addOperation:blockOp];
        [m_engQueue waitUntilAllOperationsAreFinished];
        
        if (! success ) {
            return nil;
        }
        
    }
    
    return self;
}

+(instancetype) sharedEngine
{
    if ( !_singletonEngine ) {
        _singletonEngine = [[CBIRDatabaseEngine alloc] initPrivate];
    }
    
    return _singletonEngine;
}

-(void)initBuiltinIndexers
{
    if ( !m_indexers ) {
        // Create the list.
        m_indexers = [[NSMutableDictionary alloc] init];
        
        // Register an LBPIndexer.
        [self registerIndexer:[[FaceIndexer alloc] init]];
    }
}

-(void)registerIndexer:(CBIRIndexer *)indexer
{
    if ( indexer ) {
        NSString * className = NSStringFromClass([indexer class]);
        
        if ( [m_indexers valueForKey:className] ) {
            [NSException raise:@"Duplicate Indexer" format:@"CBIRIndexer of type %@ is already registered", className];
        } else {
            [m_indexers setObject:indexer forKey:className];
            NSLog(@"Registering CBIRIndexer %@ : %@", className, indexer);
        }
        
    }
}

-(const CBIRIndexer * )getIndexer:(NSString *)indexerName
{
    CBIRIndexer * indexer = [m_indexers objectForKey:indexerName];
    return indexer;
}

-(CBIRIndexResult *)indexImage:(CBIRDocument *)imgDoc
{
    __block CBIRDocument * doc = imgDoc;
    __block CBIRIndexResult * result = nil;
    
    // Create an NSBlockOperation to perform indexing and ensure
    // that we wait until all operations are complete.
    void (^indexBlock)(void) = ^void(void) {
        
        NSLog(@"running index block");
        
        NSEnumerator * e = [m_indexers keyEnumerator];
        NSString * indexerName = nil;
        
        CBLDocument * cblDoc = [[self databaseForName:CBIR_IMAGE_DB_NAME] documentWithID:doc.persistentID];
        
        // For each registered CBIRIndexer object, generate a descriptor object
        // for the given image.  Store the descriptor object in a database document.
        while ( (indexerName = [e nextObject]) != nil ) {
            //NSLog(@"running indexer. name: %@", indexerName);
            const CBIRIndexer * indexerObj = [self getIndexer:indexerName];
            
            // CBIRIndexer objects must write the index data into the document.
            // TODO:  It might be smart to wrap the CBLDocument in an object that
            //        guarantees name uniqueness, so that indexers aren't stepping
            //        on one another's data.
            result = [indexerObj indexImage:doc cblDocument:cblDoc];
        }
        
    };
    
    NSBlockOperation * blockOp = [NSBlockOperation blockOperationWithBlock:indexBlock];
    [m_engQueue addOperation:blockOp];
    
    // TODO: Consider not waiting until all operations are done.
    [m_engQueue waitUntilAllOperationsAreFinished];
    NSLog(@"CBIRDatabaseEngine.  Done indexing.");
    
    return result;
}

-(CBLDatabase *)databaseForName:(NSString *)name
{
    NSError * error = nil;
    CBLDatabase * dbRef = [m_cblManager databaseNamed:name error:&error];
    
    if ( error ) {
        NSLog(@"databaseForName: Database could not be resolved by name: %@ error: %@", name, error);
    } else {
        NSLog(@"databaseForName: Database %@ resolved.", name);
    }
    
    return dbRef;
}

-(NSError *)deleteDatabaseNamed:(NSString *)name
{
    NSError * err = nil;
    [[self databaseForName:name] deleteDatabase:&err];
    
    if ( err ) {
        NSLog(@"deleteDatabaseNamed: %@ failed with error: %@", name, err);
    } else {
        NSLog(@"deleteDatabaseNamed: database %@ successfully deleted.", name);
    }
    
    return err;
}


@end
