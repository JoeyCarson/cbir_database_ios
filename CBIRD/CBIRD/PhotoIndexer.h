//
//  PhotoIndexer.h
//  CBIRD
//
//  Created by Joseph Carson on 9/30/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PHContentEditingInput;

// Callback style for PHImageManager to retrieve image.  No metadata though...
typedef void (^PHAssetResponseHandler)(UIImage * _Nullable result, NSDictionary * _Nullable info);

typedef void (^PHAssetContentEditingResponseHandler)(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nullable info);

typedef void (^PHImageManagerDataResponseHandler)(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info);

@class PHFetchOptions;


@protocol PhotoIndexerDelegate

-(void)progressUpdated:(CGFloat)progress filteredImage:(UIImage * _Nullable)filteredImage;

@end

/**
 * Utility class used for indexing user images into the CBIRD.
 */
@interface PhotoIndexer : NSObject

@property (nonatomic, weak) id<PhotoIndexerDelegate> delegate;

-(instancetype)initWithDelegate:(id<PhotoIndexerDelegate>)delegate;

// pauses the indexing operations.
-(void)pause;

// resumes the indexing operations.
-(void)resume;

// Wrapper method for fetchAssetsWithOptions that indexes all returned assets.
// This method will provide feedback regarding the status of the database indexing procedure.
// The calling module mustn't attempt a query while the indexing procedure is running, lest
// the results may not included indexed properties.  This could probably be improved, but it's
// fine for now.
-(void)fetchAndIndexAssetsWithOptions:(nullable PHFetchOptions *)options delegate:(_Nullable id<PhotoIndexerDelegate>)delegate;

@end
