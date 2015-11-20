//
//  ResultsViewController.m
//  CBIRD
//
//  Created by Joseph Carson on 11/19/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
#import <CBIRDatabase/CBIRDatabase.h>
#import <Photos/Photos.h>

#import "ResultsViewController.h"
#import "PhotoIndexer.h"


@implementation FaceQueryResultCell
{
    UIImageView * m_imageView;
}

@synthesize image = _image;

-(void)setImage:(UIImage *)image
{
    if ( !m_imageView ) {
        m_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [self.contentView addSubview:m_imageView];
        m_imageView.contentMode = UIViewContentModeScaleAspectFit;
        m_imageView.backgroundColor = [UIColor blueColor];
    }
    
    m_imageView.image = self.image;
}

@end




@implementation ResultsViewController
{
    FaceQuery * m_faceQuery;
    NSMutableArray * m_faceResultImages;
}

-(instancetype)init
{
    UICollectionViewFlowLayout * layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake(100, 100);
    
    self = [super initWithCollectionViewLayout:layout];
    return self;
}

-(void)viewDidLoad
{
    self.view.backgroundColor = [UIColor blackColor];
    [self.collectionView registerClass: [FaceQueryResultCell class] forCellWithReuseIdentifier:NSStringFromClass([FaceQueryResultCell class])];
}

-(void)executeQuery:(CIImage *)faceImage feature:(CIFaceFeature *)feature
{
    // TODO: Clear results and other faceQuery state.  Cancel the query if possible.
    
    // Only run the query if we have't done so yet.
    m_faceQuery= [[FaceQuery alloc] initWithFaceImage:faceImage
                                         withFeature:feature
                                         andDelegate:self];
    
    [[CBIRDatabaseEngine sharedEngine] execQuery:m_faceQuery];
}

-(void)stateUpdated:(CBIR_QUERY_STATE)state
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSLog(@"stateUpdated: %ld", (long)state);
        if ( state == QUERY_ERROR ) {
            
        } else if ( state == QUERY_COMPLETE ){
            
            NSMutableArray * localIDs = [[NSMutableArray alloc] init];
            m_faceResultImages = [[NSMutableArray alloc] init];
            
            // Load 10 images from the results.
            for ( NSUInteger i = 0; i < 30; i++ ) {
                FaceDataResult * result = [m_faceQuery dequeueResult];
                NSLog(@"result: %f", result.differenceSum);
                [localIDs addObject:result.imageDocumentID];
            }
            
            PHFetchResult<PHAsset *> * assets = [PHAsset fetchAssetsWithLocalIdentifiers:localIDs options:nil];
            for ( PHAsset * asset in assets ) {
                
                PHAssetResponseHandler imageCallback = ^void(UIImage * image, NSDictionary * info) {
                    NSLog(@"imageCallback: %@", info);
                    [m_faceResultImages addObject:image];
                };

                PHImageRequestOptions * options = [[PHImageRequestOptions alloc] init];
                options.networkAccessAllowed = NO;
                options.synchronous = YES;
                
                CGSize imageSize = CGSizeMake(80, 80);
                [[PHImageManager defaultManager] requestImageForAsset:asset
                                                           targetSize:imageSize
                                                          contentMode:PHImageContentModeAspectFit
                                                              options:options
                                                        resultHandler:imageCallback];
            }
            
            
            [self.collectionView reloadData];
        }
    });
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if ( section == 0 ) {
        return m_faceResultImages.count;
    }
    
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString * reuseID = NSStringFromClass([FaceQueryResultCell class]);
    FaceQueryResultCell * cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:reuseID forIndexPath:indexPath];
    cell.image = m_faceResultImages[indexPath.item];
    cell.backgroundColor = [UIColor redColor];
    
    return cell;
}


@end
