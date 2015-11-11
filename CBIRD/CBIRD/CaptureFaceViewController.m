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
{
    CGRect viewFrame;
}
@end

@implementation CaptureFaceViewController

@synthesize fullSizeImageView = _fullSizeImageView;
@synthesize faceFeatures = _faceFeatures;
@synthesize selectedFaceImage = _selectedFaceImage;

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if ( self ) {
        self->viewFrame = frame;
    }
    //return [super initWithNibName:@"CaptureFaceView" bundle:nil];
    return self;
}

-(void)loadView
{
    self.view = [[UIView alloc] initWithFrame:self->viewFrame];
    CGRect imageFrame = CGRectMake(viewFrame.origin.x + 20, viewFrame.origin.y + 20, viewFrame.size.width - 40, 400);
    self.fullSizeImageView = [[UIImageView alloc] initWithFrame:imageFrame];
    
    [self.view addSubview:self.fullSizeImageView];
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
    
    // The dimensions of the actual image that the view is showing.  Note that this is only the size.
    // Chances are the image in the view is actually offset a bit, so we need to determine that.
    CGSize imageSizePts = [self sizePixelsToPoints:self.fullSizeImageView.image.size];
    
    // The scale factor from of the rendered image inside the ImageView.
    CGRect viewBounds = self.fullSizeImageView.bounds;
    CGSize renderedImageScale = CGSizeMake(viewBounds.size.width / imageSizePts.width,
                                           viewBounds.size.height / imageSizePts.height);
    
    // Now that we know the rendered image scale, we can use it to determine the actual image rectangle.
    CGRect viewRect = self.fullSizeImageView.bounds;
    CGRect renderedImageRect = CGRectMake((0.5 * viewRect.size.width) - (0.5 * imageSizePts.width * renderedImageScale.width),
                                          (0.5 * viewRect.size.height) - (0.5 * imageSizePts.height * renderedImageScale.height),
                                          imageSizePts.width * renderedImageScale.width,
                                          imageSizePts.height * renderedImageScale.height);
    
    // Get the faces inside the image.
    CIImage * img = [CIImage imageWithCGImage:self.fullSizeImageView.image.CGImage];
    _faceFeatures = [ImageUtil detectFaces:img];
    
    // The face rectangles are coming CoreImage, meaning that they're in the bottom left coordinate
    // system.  We need to convert from the bottom left to top left.
    CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
    transform = CGAffineTransformTranslate(transform, 0, -self.fullSizeImageView.image.size.height);
    
    for ( CIFaceFeature * feature in _faceFeatures ) {

        CGRect uiKitFaceBounds = CGRectApplyAffineTransform(feature.bounds, transform);;
        CGRect pointRect = [self rectPixelsToPoints:uiKitFaceBounds];
        
        pointRect.origin.x *= renderedImageScale.width;
        pointRect.origin.y *= renderedImageScale.height;
        pointRect.size.width *= renderedImageScale.width;
        pointRect.size.height *= renderedImageScale.height;
        
        pointRect.origin.x += renderedImageRect.origin.x;
        pointRect.origin.y += renderedImageRect.origin.y;
        
        TargetRectangleView * rectView = [[TargetRectangleView alloc] initWithFrame:pointRect];
        rectView.rectColor = [UIColor yellowColor];
        
        [self.fullSizeImageView addSubview:rectView];
    }

}

// Scales the given rect in pixels to point scale.
-(CGRect)rectPixelsToPoints:(CGRect)rect
{
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect scaledRect = CGRectMake(rect.origin.x / scale, rect.origin.y / scale, rect.size.width/scale, rect.size.height/scale);
    return scaledRect;
}

// Scales the given size in pixels to point scale.
-(CGSize)sizePixelsToPoints:(CGSize)size
{
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGSize scaledSize = CGSizeMake(size.width/scale, size.height/scale);
    return scaledSize;
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
