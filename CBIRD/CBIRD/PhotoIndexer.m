//
//  PhotoIndexer.m
//  CBIRD
//
//  Created by Joseph Carson on 9/30/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
#import <CBIRDatabase/CBIRDatabase.h>
#import <Photos/Photos.h>

#import "PhotoIndexer.h"

#define ASSET_INDEXER_QUEUE_NAME "cbird_asset_indexer_queue"
#define ASSET_INDEX_WORKER_QUEUE_NAME "cbird_asset_index_worker_queue"

@implementation PhotoIndexer
{
    NSOperationQueue * m_indexOpQueue;
}

@synthesize delegate = _delegate;

- (instancetype) initWithDelegate:(id<PhotoIndexerDelegate> )delegate
{
    self = [super init];
    if ( self ) {
        self.delegate = delegate;
        
        dispatch_queue_t index_queue = dispatch_queue_create(ASSET_INDEXER_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
        m_indexOpQueue = [[NSOperationQueue alloc] init];
        m_indexOpQueue.maxConcurrentOperationCount = 1;
        m_indexOpQueue.underlyingQueue = index_queue;
    }
    return self;
}

-(BOOL)isRunning
{
    return !m_indexOpQueue.suspended;
}

-(void)pause
{
    [m_indexOpQueue setSuspended:YES];
}

-(void)resume
{
    m_indexOpQueue.suspended = NO;
}

-(void) dealloc
{
    [m_indexOpQueue cancelAllOperations];
    [m_indexOpQueue waitUntilAllOperationsAreFinished];
}

-(void)fetchAndIndexAssetsWithOptions:(nullable PHFetchOptions *)options
{
    
    __block id<PhotoIndexerDelegate> blockDelegate = self.delegate;
    if ( !options ) {
        options = [PHFetchOptions new];
    }
    
    options.predicate = [NSPredicate predicateWithFormat:@"(mediaType == %d)", PHAssetMediaTypeImage];

    // Fetch all assets.
    PHFetchResult<PHAsset *> * result = [PHAsset fetchAssetsWithOptions:options];
    
    // Start the progress at 10% just to get started.
    __block CGFloat progress = 0.10;
    [blockDelegate progressUpdated:progress filteredImage:nil];
    
    // Determine how much is left to get to 100% and the percentage of
    // completion for each document (progressStep).
    NSUInteger total = result.count;
    CGFloat progressLeft = 1.0 - progress;
    CGFloat progressStep = progressLeft / total;
    
    for ( NSUInteger i = 0; i < total; i++ ) {

        void (^indexBlock)(void) = ^void() {
            
            PHAsset * asset = [result objectAtIndex:i];
            
            // TODO: Change logic to check if this object is indexed.
            BOOL exists = ([[CBIRDatabaseEngine sharedEngine] getDocument:asset.localIdentifier] != nil);
            __block CBIRIndexResult * indexResult = nil;
            
            if ( !exists )
            {
                // The indexing process runs on an anonymous GCD queue on an unknown background thread, which
                // does use an auto release pool.  However, since we're loading potentially many images, each
                // fairly large, will not return back to the GCD runloop in order such that the pool will be
                // drained.  This explicit usage of an auto release pool ensures clean up of image objects
                // as soon as we're done indexing each one.  See Apple's documentation memory management with
                // GCD queues for more information.
                // https://developer.apple.com/library/ios/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationQueues/OperationQueues.html
                @autoreleasepool
                {
                    
                    CGSize size;
                    size.width = asset.pixelWidth;
                    size.height = asset.pixelHeight;
                    
                    // Extract the local asset ID to name the document with.
                    NSString * localID = asset.localIdentifier;
                    
                    PHImageManagerDataResponseHandler imageDataCallback = ^void(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info)
                    {
                        static UInt32 i = 0;
                        NSLog(@"imageData callback. %u %@", ++i, info.description);
                        NSError * error = info[PHImageErrorKey];
                        
                        if ( error ) {
                            NSLog(@"imageData callback. error: %@", error);
                            return;
                        }
                        
                        NSURL * url = info[@"PHImageFileURLKey"];
                        NSLog(@"imageData callback.  url: %@", url);
                        
                        
                        if ( imageData ) {
                            
                            CIImage * img = [self writeAssetToTmp:asset date:imageData];
                            
                            if ( img ) {
                            
                                // Add it to a new document object.
                                // TODO: Change this CBIRDocument class to something that makes more sense.
                                // For instance, something that can be used for output as well as input.
                                // Consider it CBIRDatabaseTransaction <- IndexImageTransaction.
                                // The goal is to have a common method to represent persistent ID's.
                                CBIRDocument * doc = [[CBIRDocument alloc] initWithCIImage:img persistentID:localID type:PH_ASSET];
                                
                                // Index it.
                                NSDate * before = [NSDate date];
                                [[CBIRDatabaseEngine sharedEngine] indexImage:doc];

                                NSDate * after = [NSDate date];
                                NSLog(@"indexing time: %f s", after.timeIntervalSince1970 - before.timeIntervalSince1970);
                                
                                // remove the temporary file that we wrote.
                                NSError * err = nil;
                                BOOL removed = [[NSFileManager defaultManager] removeItemAtURL:img.url error:&err];
                                if ( !removed ) {
                                    NSLog(@"remove fails: %@", err);
                                }
                            }
                        }
                        
                    };
                    
                    // Retrieve the image data using a synchronous callback that won't hit the network.
                    PHImageRequestOptions * opts = [[PHImageRequestOptions alloc] init];
                    opts.synchronous = YES;
                    opts.networkAccessAllowed = NO;
                    
                    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:opts resultHandler:imageDataCallback];
                }
                
            }
            
            // We should also pass an update state to the communicate
            // failure or completion of the indexer process.
            [self.delegate progressUpdated:(progress += progressStep) filteredImage:indexResult.filteredImage];
            NSLog(@"processing complete.");
        };
        
        [m_indexOpQueue addOperationWithBlock:indexBlock];
    }
    
}

// Copy the image from the private storage into temporary storage.
-(CIImage *)writeAssetToTmp:(PHAsset *)asset date:(NSData *)imageData
{
    // Generate a unique url.
    static NSUInteger c = 0;
    NSString * urlStr = [NSString stringWithFormat:@"file://%@_%lu", NSTemporaryDirectory(), (unsigned long)c++];
    NSURL * url = [NSURL URLWithString:urlStr];
    
    // Remove tmp file from previous runs.
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    
    // First check whether or not the image data will actually work.
    // If the data is bad, the temp image will be nil.
    CIImage * temp = [CIImage imageWithData:imageData];
    CIImage * img = nil;
    
    if ( temp ) {
        BOOL success = [imageData writeToURL:url atomically:NO];
        if ( success ) {
            img = [CIImage imageWithContentsOfURL:url];
            //NSLog(@"image: %@", image.description);
        }
    }
    
    return img;
}


@end
