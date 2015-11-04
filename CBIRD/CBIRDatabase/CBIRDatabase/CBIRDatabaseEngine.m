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


static const NSString * const kCBIROutputDocument = @"outputDocument";
static const NSString * const kCBIRPersistentID = @"persistentID";

@interface CBIRDatabaseEngine(Private)

-(instancetype)initPrivate;

-(CBLDatabase *)databaseForName:(NSString *)name;

@end

CBIRDatabaseEngine * _singletonEngine;

@implementation CBIRDatabaseEngine
{
    // All registered indexers.
    NSMutableDictionary * m_indexers;
    
    // Manager for CBL.  Don't use sharedInstance as
    // it's only recommended to be used on the main thread.
    CBLManager * m_cblManager;
    
    // Thread for database transactions.
    NSThread * m_dbThread;
}

- (BOOL)isRunning
{
    return m_dbThread.executing;
}

- (BOOL)isTerminated
{
    return m_dbThread.cancelled;
}

+(instancetype) sharedEngine
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _singletonEngine = [[CBIRDatabaseEngine alloc] initPrivate];
    });
    
    return _singletonEngine;
}

+(BOOL) shutdown
{
    __block BOOL shutdownSuccess = NO;
    if ( _singletonEngine ) {
        static dispatch_once_t shutdownOnce;
        dispatch_once(&shutdownOnce, ^{
            // terminate the main thread when it's checked.
            [_singletonEngine terminate];
            
            // Spin until complete.
            while ( _singletonEngine.isRunning ) { /* spin until done.*/ }
            NSLog(@"CBIRDatabaseEngine thread termination complete.");
            
            // Now forget the singleton instance.
            // The dealloc call will also set the
            _singletonEngine = nil;
            shutdownSuccess = YES;
            
            NSLog(@"CBIRDatabaseEngine shutdown complete.");
        });
    } else {
        NSLog(@"CBIRDatabaseEngine shutdown called, but singleton doesn't exist.");
    }
    
    return shutdownSuccess;
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
        m_dbThread = [[NSThread alloc] initWithTarget:self selector:@selector(dBThread) object:nil];
        [m_dbThread start];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"CBIRDatabaseEngine dealloc: terminating engine thread.");
    [CBIRDatabaseEngine shutdown];
}

- (void) terminate
{
    NSLog(@"CBIRDatabaseEngine thread terminated set.");
    [m_dbThread cancel];
}

- (void)dBThread
{
    // Set up couchbase lite manager.
    NSError * error = nil;
    m_cblManager = [[CBLManager alloc] initWithDirectory:CBLManager.defaultDirectory options:nil error:&error];
    
    if ( error ) {
        NSLog(@"CBIRDatabaseEngine: CBLManager instantiation failure: %@", error);
        [self terminate];
    } else {
        // Add all built in supported indexers.
        [self initBuiltinIndexers];
        
        // Trash the database to help with debugging in early stages of development.
        //[self deleteDatabaseNamed:CBIR_IMAGE_DB_NAME];
    }
    
    while ( !self.isTerminated ) {
        @autoreleasepool {
            NSDate * until = [NSDate dateWithTimeInterval:.10 sinceDate:[NSDate date]];
            [[NSRunLoop currentRunLoop] runUntilDate:until];
        }
    }
    
    NSLog(@"CBIRDatabaseEngine thread done.");
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
    [self performSelector:@selector(registerIndexerInternal:) onThread:m_dbThread withObject:indexer waitUntilDone:YES];
}

-(void)registerIndexerInternal:(CBIRIndexer *)indexer
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
    [self performSelector:@selector(indexImageInternal:) onThread:m_dbThread withObject:imgDoc waitUntilDone:YES];
    return nil;
}

- (void)indexImageInternal:(CBIRDocument *)imgDoc
{
    NSLog(@"running index worker");
    
    NSEnumerator * e = [m_indexers keyEnumerator];
    NSString * indexerName = nil;
    
    CBLDocument * cblDoc = [[self databaseForName:CBIR_IMAGE_DB_NAME] documentWithID:imgDoc.persistentID];
    
    // Use each indexer to extract features and write them into the CBLDocument.
    while ( (indexerName = [e nextObject]) != nil ) {

        //NSLog(@"running indexer. name: %@", indexerName);
        const CBIRIndexer * indexerObj = [self getIndexer:indexerName];
        
        // CBIRIndexer objects must write the index data into the document.
        // TODO:  It might be smart to wrap the CBLDocument in an object that
        //        guarantees name uniqueness, so that indexers aren't stepping
        //        on one another's data.
        [indexerObj indexImage:imgDoc cblDocument:cblDoc];
    }
}

-(CBLDocument *)getDocument:(NSString *)persistentID
{
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    params[kCBIRPersistentID] = persistentID;
    
    [self performSelector:@selector(getDocumentInternal:) onThread:m_dbThread withObject:params waitUntilDone:YES];
    
    CBLDocument * outputDocument = params[kCBIROutputDocument];
    return outputDocument;
}

-(void)getDocumentInternal:(NSMutableDictionary *)params
{
    NSString * persistentID = params[kCBIRPersistentID];
    CBLDocument * doc = [[self databaseForName:CBIR_IMAGE_DB_NAME] existingDocumentWithID:persistentID];
    params[kCBIROutputDocument] = doc;
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
