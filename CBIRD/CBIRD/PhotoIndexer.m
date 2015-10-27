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
    NSOperationQueue * m_indexOutputQueue;
}

- (instancetype) init
{
    self = [super init];
    if ( self ) {
        dispatch_queue_t index_queue = dispatch_queue_create(ASSET_INDEXER_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
        m_indexOpQueue = [[NSOperationQueue alloc] init];
        m_indexOpQueue.underlyingQueue = index_queue;
        
        dispatch_queue_t index_out_queue = dispatch_queue_create(ASSET_INDEXER_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
        m_indexOutputQueue = [[NSOperationQueue alloc] init];
        m_indexOutputQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        m_indexOutputQueue.underlyingQueue = index_out_queue;
        
    }
    return self;
}

-(void)pause
{
    m_indexOpQueue.suspended = YES;
}

-(void)resume
{
    m_indexOpQueue.suspended = NO;
}

-(void)fetchAndIndexAssetsWithOptions:(nullable PHFetchOptions *)options delegate:(_Nullable id<PhotoIndexerDelegate>)delegate
{
    
    __block id<PhotoIndexerDelegate> blockDelegate = delegate;
    

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
            // TODO: Change logic to check if this object is indexed.
            BOOL exists = NO;
            
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
                    PHAsset * asset = [result objectAtIndex:i];
                    // NSLog(@"%@", [asset description]);
                    
                    CGSize size;
                    size.width = asset.pixelWidth;
                    size.height = asset.pixelHeight;
                    
                    // Extract the local asset ID to name the document with.
                    NSString * localID = asset.localIdentifier;
                    
                    // F you very much Apple...  This callback will always go to the main thread regardless of what thread requested the
                    // image data.  This is the only API that can directly be reliably used to pick up a CIImage with metadata properties
                    // populated (necessary for face detection and other image processing operations).  But with it always dispatching to the
                    // main thread, it's of no use since it will block UI interaction.
                    PHAssetContentEditingResponseHandler requestBlock = ^void(PHContentEditingInput * contentEditingInput, NSDictionary * info) {
                        
                        NSError * error = info[PHContentEditingInputErrorKey];
                        
                        if ( error ) {
                            NSLog(@"returning early error found. %@", error.description);
                            return;
                        }
                        
                        if ( contentEditingInput.fullSizeImageURL ) {
                            
                            NSLog(@"ready for processing.");
                            NSURL * url = [contentEditingInput.fullSizeImageURL copy];
                            
                            __block CIImage * img = [self cloneImageToTmp:url];
                            
                            if ( img ) {
                                NSLog(@"valid URL.  queue indexer.");
                                void (^indexBlock)() = ^void() {
                                
                                    // Add it to a new document object.
                                    CBIRDocument * doc = [[CBIRDocument alloc] initWithCIImage:img persistentID:localID type:PH_ASSET];
                                    
                                    // Index it.
                                    NSDate * before = [NSDate date];
                                    indexResult = [[CBIRDatabaseEngine sharedEngine] indexImage:doc];
                                    
                                    // We should also pass an update state to the communicate
                                    // failure or completion of the indexer process.
                                    NSDate * after = [NSDate date];
                                    NSLog(@"indexing time: %f s", after.timeIntervalSince1970 - before.timeIntervalSince1970);
                                    
                                    // remove the temporary file that we wrote.
                                    [[NSFileManager defaultManager] removeItemAtURL:img.url error:nil];
                                    
                                    [delegate progressUpdated:(progress += progressStep) filteredImage:indexResult.filteredImage];
                                    NSLog(@"processing complete.");
                                };
                                
                                [m_indexOutputQueue addOperationWithBlock: indexBlock];
                            }
                        }
                        
                    };
                    
                    PHContentEditingInputRequestOptions *opts = [[PHContentEditingInputRequestOptions alloc] init];
                    opts.networkAccessAllowed = NO;
                    
                    NSLog(@"adding request.");
                    [asset requestContentEditingInputWithOptions:opts completionHandler:requestBlock];
                    
                }
                
            }
        };
        
        [m_indexOpQueue addOperationWithBlock:indexBlock];
        
    }
    
}

// Copy the image from the private storage into temporary storage.
-(CIImage *)cloneImageToTmp:(NSURL *)fromImageURL
{
    CIImage * img = nil;
    static NSUInteger c = 0;
    NSString * urlStr = [NSString stringWithFormat:@"file://%@_%lu", NSTemporaryDirectory(), (unsigned long)c++];
    NSURL * url = [NSURL URLWithString:urlStr];
    
    NSError * error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    BOOL success = [[NSFileManager defaultManager] copyItemAtURL:fromImageURL toURL:url error:&error];
    
    if ( !success || error ) {
        NSLog(@"clone image to temp failed. %@", error);
    } else {
        img = [CIImage imageWithContentsOfURL:url];
    }
    
    return img;
}


@end
