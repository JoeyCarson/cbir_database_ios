//
//  ResultsViewController.h
//  CBIRD
//
//  Created by Joseph Carson on 11/19/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FaceQueryResultCell : UICollectionViewCell

@property (nonatomic) UIImage * image;

@property (nonatomic) NSUInteger index;

@end

@interface ResultsViewController : UICollectionViewController<CBIRQueryDelegate>

-(instancetype)init NS_DESIGNATED_INITIALIZER;

-(void)executeQuery:(CIImage *)faceImage feature:(CIFaceFeature *)feature;

@end
