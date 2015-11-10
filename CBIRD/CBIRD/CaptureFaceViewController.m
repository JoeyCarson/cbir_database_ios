//
//  CaptureFaceViewController.m
//  CBIRD
//
//  Created by Joseph Carson on 11/9/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CaptureFaceViewController.h"
#import "TargetRectangleView.h"
#import <CBIRDatabase/CBIRDatabase.h>

@interface CaptureFaceViewController ()

@end

@implementation CaptureFaceViewController

@synthesize fullSizeImageView = _fullSizeImageView;

-(instancetype)init
{
    return [super initWithNibName:@"CaptureFaceView" bundle:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.fullSizeImageView.image = [UIImage imageNamed:@"rancid_show.jpg"];
    self.fullSizeImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.fullSizeImageView.backgroundColor = [UIColor greenColor];
    self.fullSizeImageView.translatesAutoresizingMaskIntoConstraints = NO;
}

-(void)viewWillAppear:(BOOL)animated
{
    [self markFaceRectangles];
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

-(void)markFaceRectangles
{
    // Remove the target rectangles.
    for ( UIView * view in self.fullSizeImageView.subviews ) {
        [view removeFromSuperview];
    }
    
    // Get the faces inside the image.
    CIImage * img = [CIImage imageWithCGImage:self.fullSizeImageView.image.CGImage];
    NSArray * faceFeatures = [ImageUtil detectFaces:img];
    
    for ( CIFaceFeature * feature in faceFeatures ) {

        CGRect rect = [self pixelsToPoints:feature.bounds];
        CGRect pointRect = [self scaleRectToImage:rect];
        
        TargetRectangleView * rectView = [[TargetRectangleView alloc] initWithFrame:pointRect];
        rectView.rectColor = [UIColor yellowColor];
        
        //[self.fullSizeImageView addSubview:rectView];
    }

}

-(CGRect)pixelsToPoints:(CGRect)rect
{
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect scaledRect = CGRectMake(rect.origin.x / scale, rect.origin.y / scale, rect.size.width/scale, rect.size.height/scale);
    return scaledRect;
}

// rect is expected to be in points.
-(CGRect)scaleRectToImage:(CGRect)rect
{
    CGRect vFrame = self.view.frame;
    CGRect imageFrame = self.fullSizeImageView.frame;
    
    CGFloat wScale =  imageFrame.size.width / vFrame.size.width;
    CGFloat hScale = imageFrame.size.height / vFrame.size.height;
    
    CGRect scaledRect = CGRectMake(rect.origin.x * wScale, rect.origin.y * hScale, rect.size.width * wScale, rect.size.height * hScale);
    return scaledRect;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
