//
//  CaptureFaceViewController.h
//  CBIRD
//
//  Created by Joseph Carson on 11/9/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CaptureFaceViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView * fullSizeImageView;
@property (nonatomic, copy) NSArray * faceFeatures;
@property (nonatomic, readonly) CIImage * selectedFaceImage;
@property (nonatomic, readonly) CIFaceFeature * selectedFaceFeature;

-(instancetype)initWithFrame:(CGRect)frame;

@end
