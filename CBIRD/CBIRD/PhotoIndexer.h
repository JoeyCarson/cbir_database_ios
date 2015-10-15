//
//  PhotoIndexer.h
//  CBIRD
//
//  Created by Joseph Carson on 9/30/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PHAssetResponseHandler)(UIImage * _Nullable result, NSDictionary * _Nullable info);

@class PHFetchOptions;


@protocol PhotoIndexerDelegate

-(void)progressUpdated:(CGFloat)progress filteredImage:(UIImage *)filteredImage;

@end

/**
 * Utility class used for indexing user images into the CBIRD.
 */
@interface PhotoIndexer : NSObject

// Wrapper method for fetchAssetsWithOptions that indexes all returned assets.
// This method will provide feedback regarding the status of the database indexing procedure.
// The calling module mustn't attempt a query while the indexing procedure is running, lest
// the results may not included indexed properties.  This could probably be improved, but it's
// fine for now.
+(void)fetchAndIndexAssetsWithOptions:(nullable PHFetchOptions *)options delegate:(_Nullable id<PhotoIndexerDelegate>)delegate;

@end
