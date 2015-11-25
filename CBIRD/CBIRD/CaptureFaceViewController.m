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
#import <CoreImage/CoreImage.h>


@interface UIImage(normalizeImage)

- (UIImage *)normalizedImage;

@end


@implementation UIImage(normalizeImage)

// Credit to http://stackoverflow.com/questions/5427656/ios-uiimagepickercontroller-result-image-orientation-after-upload
// UIImage (UIKit) and CIImage use different coordinate spaces and this method can be used to normalize the orientation.
// This is the same problem when computing the scaled face recangle offsets in the rendered UIImage.
- (UIImage *)normalizedImage {
    if (self.imageOrientation == UIImageOrientationUp) return self;
    
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    [self drawInRect:(CGRect){0, 0, self.size}];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}

@end


@interface CaptureFaceViewController ()
{
    CGRect viewFrame;
    NSMutableDictionary<NSValue *, CIFaceFeature *> * rectangleViews;
    TargetRectangleView * selectedRectView;
    UIImagePickerController * imagePickerController;
    NSNumber * orientationOfCameraImage;
}
@end

@implementation CaptureFaceViewController

@synthesize fullSizeImageView = _fullSizeImageView;
@synthesize faceFeatures = _faceFeatures;
@synthesize selectedFaceImage = _selectedFaceImage;
@synthesize selectedFaceFeature = _selectedFaceFeature;

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if ( self ) {
        self->viewFrame = frame;
        rectangleViews = [[NSMutableDictionary alloc] init];
    }

    return self;
}

-(void)loadView
{
    self.view = [[UIView alloc] initWithFrame:self->viewFrame];
    self.view.backgroundColor = [UIColor blackColor];
    
    CGRect imageFrame = CGRectMake(viewFrame.origin.x + 20, viewFrame.origin.y + 80, viewFrame.size.width - 40, 400);
    self.fullSizeImageView = [[UIImageView alloc] initWithFrame:imageFrame];
    self.fullSizeImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.fullSizeImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.fullSizeImageView.userInteractionEnabled = YES;
    [self updateMainImage:[UIImage imageNamed:@"rancid_show.jpg"]];
    
    UIButton * doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    doneButton.opaque = NO;
    doneButton.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.4];
    doneButton.frame = CGRectMake(20, 20, 80, 40);
    [doneButton setTitle:@"Done" forState:UIControlStateNormal];
    [doneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    doneButton.backgroundColor = [UIColor whiteColor];
    [doneButton addTarget:self action:@selector(onDone:) forControlEvents:UIControlEventTouchUpInside];
    doneButton.translatesAutoresizingMaskIntoConstraints = false;
    
    
    UIButton * cameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cameraButton.opaque = NO;
    cameraButton.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.4];
    cameraButton.frame = CGRectMake(self.view.bounds.size.width - 100, 20, 80, 40);
    [cameraButton setTitle:@"Camera" forState:UIControlStateNormal];
    [cameraButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    cameraButton.backgroundColor = [UIColor whiteColor];
    [cameraButton addTarget:self action:@selector(onOpenCamera:) forControlEvents:UIControlEventTouchUpInside];
    cameraButton.translatesAutoresizingMaskIntoConstraints = false;

    
    [self.view addSubview:self.fullSizeImageView];
    [self.view addSubview:doneButton];
    [self.view addSubview:cameraButton];
}

-(void)updateMainImage:(UIImage *)image
{
    self.fullSizeImageView.image = image;
    [self markFaceRectangles];
}

-(void)viewWillAppear:(BOOL)animated
{
    [self markFaceRectangles];
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

-(void)onDone:(UIEvent *)buttonEvent
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)onOpenCamera:(UIEvent *)buttonEvent
{
    if ( !imagePickerController ) {
        imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera; // default mediaType is image.
    }
    
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
{
    NSLog(@"%s info: %@", __FUNCTION__, info);
    UIImage * capturedImage = [info[UIImagePickerControllerOriginalImage] normalizedImage] ;
    
    //CIImage * image = CIImage imageWith
    NSDictionary *metadataDict = info[UIImagePickerControllerMediaMetadata];
    orientationOfCameraImage = metadataDict[@"Orientation"];
    orientationOfCameraImage = [self convertUIImageOrientationToCIImageOrientation:capturedImage.imageOrientation ];
    
    self.fullSizeImageView.image = capturedImage;
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(NSNumber *)convertUIImageOrientationToCIImageOrientation:(UIImageOrientation)inputOrientation
{
    NSUInteger exifOrientation = 1;
    
    
    switch ( inputOrientation ) {
        case UIImageOrientationUp:
            exifOrientation = 1;
            break;
        case UIImageOrientationDown:
            exifOrientation = 3;
            break;
        case UIImageOrientationLeft:
            exifOrientation = 8;
            break;
        case UIImageOrientationRight:
            exifOrientation = 6;
            break;
        case UIImageOrientationUpMirrored:
            exifOrientation = 2;
            break;
        case UIImageOrientationDownMirrored:
            exifOrientation = 4;
            break;
        case UIImageOrientationLeftMirrored:
            exifOrientation = 5;
            break;
        case UIImageOrientationRightMirrored:
            exifOrientation = 7;
            break;
        default:
            break;
    }

    return [NSNumber numberWithUnsignedInteger:exifOrientation];
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
    
    // Get the faces inside the image.  As of today, the CGImage is oriented as expected to be. No rotation necessary.
    CIImage * img = [CIImage imageWithCGImage:self.fullSizeImageView.image.CGImage];
    //[ImageUtil dumpDebugImage:img];
    
    NSLog(@"img properties: %@", img.properties);
    
    
    NSDictionary * overrideOptions = orientationOfCameraImage ? @{CIDetectorImageOrientation:orientationOfCameraImage} : nil;
    _faceFeatures = [ImageUtil detectFaces:img overrideOpts:overrideOptions];
    
    // The face rectangles are coming CoreImage, meaning that they're in the bottom left coordinate
    // system.  We need to convert from the bottom left to top left.
    CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
    transform = CGAffineTransformTranslate(transform, 0, -self.fullSizeImageView.image.size.height);
    
    for ( CIFaceFeature * feature in _faceFeatures ) {

        // Transform the found coordinates to upper right hand corner pixel space.  Then convert that to points.
        CGRect uiKitFaceBounds = CGRectApplyAffineTransform(feature.bounds, transform);
        CGRect pointRect = [ImageUtil rectPixelsToPoints:uiKitFaceBounds];
        
        // scale the point rect into the rendered image scale.
        pointRect.origin.x *= renderedImageScale.width;
        pointRect.origin.y *= renderedImageScale.height;
        pointRect.size.width *= renderedImageScale.width;
        pointRect.size.height *= renderedImageScale.height;
        
        // Offset the rectangle by any space outside of the image rect.  This is area taken up by the UIImageView
        // around the image itself.
        pointRect.origin.x += renderedImageRect.origin.x;
        pointRect.origin.y += renderedImageRect.origin.y;
        
        // Create the rectangle view.
        TargetRectangleView * rectView = [[TargetRectangleView alloc] initWithFrame:pointRect];
        rectView.rectColor = [UIColor yellowColor];
        
        UITapGestureRecognizer *tapRecognzier = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onRectSelected:)];
        tapRecognzier.numberOfTapsRequired = 1;
        tapRecognzier.numberOfTouchesRequired = 1;
        [rectView addGestureRecognizer:tapRecognzier];
        
        // TODO: This is bad.  Storing rectviews like this (unretained) causes a crash
        // somewhere in the UI framework.  It seems like the view lets go of the object
        // and since it's not retained in the NSDictionary/NSValue, it's released.
        NSValue * rectViewValue = [NSValue valueWithNonretainedObject:rectView];
        rectangleViews[rectViewValue] = feature;
        
        
        [self.fullSizeImageView addSubview:rectView];
    }

    [self.fullSizeImageView setNeedsDisplay];
}

-(void)onRectSelected:(UIGestureRecognizer *)gestureRecognizer
{
    //NSLog(@"onRectSelected: gestureRecognizer: %@", gestureRecognizer);
    
    if ( gestureRecognizer.view.class == [TargetRectangleView class] ) {
        TargetRectangleView * rectView = (TargetRectangleView *)gestureRecognizer.view;
        
        NSValue * val = [NSValue valueWithNonretainedObject:(rectView)];
        CIFaceFeature * faceAssociatedWithView = [rectangleViews objectForKey:val];
        
        if ( faceAssociatedWithView ) {
            [self updateSelectedFace:faceAssociatedWithView andView:rectView];
        } else {
            NSLog(@"Oh Noes!!");
        }
    }
}

-(void)updateSelectedFace:(CIFaceFeature *)faceFeature andView:(TargetRectangleView *)rectView
{
    NSArray * views = self.fullSizeImageView.subviews;
    
    for (UIView * view in views ) {
        TargetRectangleView * keyView = (TargetRectangleView *)view;
        keyView.rectColor = [UIColor yellowColor];
        [keyView setNeedsDisplay];
    }
    
    if ( rectView == selectedRectView ) {
        // Unset this view.
        selectedRectView = nil;
        [self updateFaceImage:nil];
    } else {
        NSLog(@"selecting faceFeature: %@", NSStringFromCGRect(faceFeature.bounds));
        selectedRectView = rectView;
        rectView.rectColor = [UIColor greenColor];
        [self updateFaceImage:faceFeature];
    }
    
    [rectView setNeedsDisplay];
}

-(void)updateFaceImage:(CIFaceFeature *)faceFeature
{
    if ( !faceFeature) {
        // We're unsetting the selected image.
        _selectedFaceImage = nil;
        _selectedFaceFeature = nil;
    } else {
        
        // We're selecting a new face image.
        CIImage * inImage = [[CIImage alloc] initWithImage:self.fullSizeImageView.image];
        NSDictionary * params = @{@"inputImage":inImage, @"inputRectangle":[CIVector vectorWithCGRect:faceFeature.bounds]};
        CIFilter * cropFilter = [CIFilter filterWithName:@"CICrop" withInputParameters:params];
        CIImage * croppedImage = cropFilter.outputImage;
        
        //[ImageUtil dumpDebugImage:croppedImage];
        
        _selectedFaceImage = croppedImage;
        _selectedFaceFeature = faceFeature;
    }
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
