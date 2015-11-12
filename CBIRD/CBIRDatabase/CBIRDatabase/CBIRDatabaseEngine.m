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


static const NSString * const kCBLOutputDocument = @"outputDocument";
static const NSString * const kCBIRPersistentID = @"persistentID";
static const NSString * const kCBIRIndexerName = @"indexerName";
static const NSString * const kCBIRIndexer = @"indexer";


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
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    params[kCBIRIndexerName] = indexerName;
    
    [self performSelector:@selector(getIndexerInternal:) onThread:m_dbThread withObject:params waitUntilDone:YES];
    
    CBIRIndexer * indexer = params[kCBIRIndexer];
    return indexer;
}

-(void)getIndexerInternal:(NSMutableDictionary *)params
{
    NSString * indexerName = params[kCBIRIndexerName];
    CBIRIndexer * indexer = [m_indexers objectForKey:indexerName];
    params[kCBIRIndexer] = indexer;
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
        CBLUnsavedRevision * unsavedRevision = [indexerObj indexImage:imgDoc cblDocument:cblDoc];
        
        NSError * error = nil;
        [unsavedRevision save:&error];
        if ( error ) {
            NSLog(@"%s error saving face data list: %@", __FUNCTION__, error);
        }
        
    }
    
    [self testDifference:cblDoc];
}

-(void)testDifference:(CBLDocument *)doc
{
    if ( doc ) {
        
        NSDictionary * p = doc.properties;
        NSArray * faceDataList = p[@"face_data_list"];
        
        if ( faceDataList ) {
        
            for ( NSUInteger i = 0; i < faceDataList.count; i++ ) {
            
                NSDictionary * faceDataMap = faceDataList[i];
                NSArray * featureList = faceDataMap[@"features"];
                
                if ( featureList.count > 0 ) {
                
                    // Put all associated histogram buffers into a single image.
                    size_t histoLengthInBytes = 256 * sizeof(float);
                    NSUInteger histoImageSize = GRID_HEIGHT_IN_BLOCKS * GRID_WIDTH_IN_BLOCKS * histoLengthInBytes;
                    unsigned char * trainingHistoImageBuffer = malloc(histoImageSize);
                    void * outputHistoPointer = trainingHistoImageBuffer;
                    
                    // Now memcpy each histogram into the buffer.
                    for ( NSUInteger featureIndex = 0; featureIndex < featureList.count; featureIndex++ ) {
                        
                        // Retrieve each attachment.
                        NSString * featureAttachmentName = featureList[featureIndex];
                        CBLAttachment * featureAttachment = [[doc currentRevision] attachmentNamed:featureAttachmentName];
                        NSData * attachmentData = featureAttachment.content;
                        
                        
                        memcpy(outputHistoPointer, attachmentData.bytes, histoLengthInBytes);
                        outputHistoPointer += histoLengthInBytes;
                    }
                    
                    // Wrap the buffer in an NSData.
                    NSData * histoImageData = [NSData dataWithBytesNoCopy:trainingHistoImageBuffer length:histoImageSize];
                    
                    // The "image" is 256 * number of blocks wide (each of which is a float).
                    CGSize histoImageDim = CGSizeMake(GRID_WIDTH_IN_BLOCKS * 256, GRID_HEIGHT_IN_BLOCKS);
                    
                    // The kCIFormatRf format equates to each "pixel" being a 32 bit float.  Each pixel should be a float
                    // from the computation 
                    CIImage * histoImage = [[CIImage alloc] initWithBitmapData:histoImageData
                                                                   bytesPerRow:(GRID_WIDTH_IN_BLOCKS * histoLengthInBytes)
                                                                          size:histoImageDim
                                                                        format:kCIFormatRf
                                                                    colorSpace:nil];
                    
                    
                    NSAssert(histoImage != nil, @"failed generating histoImage");
                    
                }
            }
        }
    }
}

-(CBLDocument *)getDocument:(NSString *)persistentID
{
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    params[kCBIRPersistentID] = persistentID;
    
    [self performSelector:@selector(getDocumentInternal:) onThread:m_dbThread withObject:params waitUntilDone:YES];
    
    CBLDocument * outputDocument = params[kCBLOutputDocument];
    return outputDocument;
}

-(void)getDocumentInternal:(NSMutableDictionary *)params
{
    NSString * persistentID = params[kCBIRPersistentID];
    CBLDocument * doc = [[self databaseForName:CBIR_IMAGE_DB_NAME] existingDocumentWithID:persistentID];
    params[kCBLOutputDocument] = doc;
}

-(CBLDocument *)newDocument:(NSString *)newDocID
{
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    params[kCBIRPersistentID] = newDocID;
    
    [self performSelector:@selector(newDocumentInternal:) onThread:m_dbThread withObject:params waitUntilDone:YES];
    
    CBLDocument * outputDocument = params[kCBLOutputDocument];
    return outputDocument;

}

-(void)newDocumentInternal:(NSMutableDictionary *)params
{
    NSString * persistentID = params[kCBIRPersistentID];
    CBLDocument * doc = [[self databaseForName:CBIR_IMAGE_DB_NAME] documentWithID:persistentID];
    params[kCBLOutputDocument] = doc;
}



-(void)execQuery:(CBIRQuery *)query
{
    [self performSelector:@selector(execQueryInternal:) onThread:m_dbThread withObject:query waitUntilDone:NO];
}

-(void)execQueryInternal:(CBIRQuery *)query
{
    [query evaluate];
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
