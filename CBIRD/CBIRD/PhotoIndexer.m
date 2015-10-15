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

@implementation PhotoIndexer

// TODO:  Define a PhotoIndexerDelegate protcol to provide UI feedback during indexing.
+(void)fetchAndIndexAssetsWithOptions:(nullable PHFetchOptions *)options delegate:(_Nullable id<PhotoIndexerDelegate>)delegate
{
    
    __block id<PhotoIndexerDelegate> blockDelegate = delegate;
    
    // Perform the indexing procedure asynchronously on GCD queue.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{

        // Fetch all assets.
        PHFetchResult<PHAsset *> * result = [PHAsset fetchAssetsWithOptions:options];
        
        // Start the progress at 10% just to get started.
        CGFloat progress = 0.10;
        [blockDelegate progressUpdated:progress filteredImage:nil];
        
        // Determine how much is left to get to 100% and the percentage of
        // completion for each document.
        NSUInteger total = result.count;
        CGFloat progressLeft = 1.0 - progress;
        CGFloat progressStep = progressLeft / total;
        
        // Run all indexers on each asset.  Prep and store the results.
        for ( NSUInteger i = 0; i < total; i++ ) {

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
                    
                    PHImageRequestOptions * options = [[PHImageRequestOptions alloc] init];
                    options.synchronous = YES;
                    
                    // Extract the local asset ID to name the document with.
                    NSString * localID = asset.localIdentifier;
                    
                    PHAssetResponseHandler indexBlock = ^void(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                        CGImageRef imageCopy = result.CGImage;
                        CBIRDocument * doc = [[CBIRDocument alloc] initWithCGImage:imageCopy persistentID:localID type:PH_ASSET];
                        indexResult = [[CBIRDatabaseEngine sharedEngine] indexImage:doc];
                    };
                    
                    // TODO: Investigate invocation nature.
                    [[PHImageManager defaultManager] requestImageForAsset:asset
                                                               targetSize:size
                                                              contentMode:PHImageContentModeDefault
                                                                  options:options
                                                            resultHandler:indexBlock];
                }
                
                // Uncomment the sleep when you want to display images.
                [NSThread sleepForTimeInterval:1.0];
            }
            
            // We should also pass an update state to the communicate
            // failure or completion of the indexer process.
            [delegate progressUpdated:(progress += progressStep) filteredImage:indexResult.filteredImage];
            
        }
        
        NSLog(@"PhotoIndexer done.");
    });
}


@end
