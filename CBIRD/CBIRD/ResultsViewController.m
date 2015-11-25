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
    UILabel * m_indexLabel;
}

@synthesize image = _image;
@synthesize index = _index;

-(UIImageView *) imageView
{
    if ( !m_imageView ) {
        m_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [self.contentView addSubview:m_imageView];
        m_imageView.contentMode = UIViewContentModeScaleAspectFit;
        m_imageView.backgroundColor = [UIColor blueColor];
    }
    
    return m_imageView;
}

-(UILabel *) labelView
{
    if ( !m_indexLabel ) {
        m_indexLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
        m_indexLabel.center = [self imageView].center;
        m_indexLabel.textColor = [UIColor whiteColor];
        [[self imageView] addSubview:m_indexLabel];
    }
    
    return m_indexLabel;
}

-(void)setImage:(UIImage *)image
{
    _image = image;
    [self imageView].image = _image;
}

-(void)setIndex:(NSUInteger)index
{
    [self labelView].text = [NSString stringWithFormat:@"%lu", index];
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
            
            m_faceResultImages = [[NSMutableArray alloc] init];
            
            // Load some images from the results.
            for ( NSUInteger i = 0; i < 10; i++ ) {
                FaceDataResult * result = [m_faceQuery dequeueResult];
                if ( result ) {
                    [m_faceResultImages addObject:[UIImage imageWithData:result.faceJPEGData]];
                }
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
    NSUInteger index = indexPath.item;
    cell.image = m_faceResultImages[index];
    cell.index = index;
    cell.backgroundColor = [UIColor redColor];
    
    [cell setNeedsDisplay];
    return cell;
}


@end
