//
//  FirstViewController.m
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "CaptureFaceViewController.h"
#import "QueryViewController.h"
#import "PhotoIndexer.h"

@interface QueryViewController ()
{
    NSTimer * timer;
    PhotoIndexer * m_indexer;
    UILabel * m_progressLabel;
}

@property (nonatomic) CaptureFaceViewController * faceCaptureController;

@end



@implementation QueryViewController

@synthesize faceCaptureController = _faceCaptureController;

-(CaptureFaceViewController *)faceCaptureController
{
    if ( !_faceCaptureController ) {
        
        _faceCaptureController = [[CaptureFaceViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    }
    
    return _faceCaptureController;
}

-(void)loadView
{

    UIToolbar * toolbar = [self buildToolbar];
    
    UIView * backgroundView = [[UIView alloc] init];
    backgroundView.backgroundColor = [UIColor blackColor];
    [backgroundView addSubview:toolbar];
    
    
    UIButton * selectImageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    selectImageButton.frame = CGRectMake(0, 0, 0, 0);
    [selectImageButton setTitle:@"Select Image" forState:UIControlStateNormal];
    [selectImageButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    selectImageButton.backgroundColor = [UIColor blackColor];
    [selectImageButton addTarget:self action:@selector(onSelectImage:) forControlEvents:UIControlEventTouchUpInside];
    selectImageButton.translatesAutoresizingMaskIntoConstraints = false;
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    UIScrollView * scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, toolbar.frame.size.height, toolbar.frame.size.width, screenBounds.size.height - toolbar.bounds.size.height)];
    scrollView.backgroundColor = [UIColor grayColor];
    
    UIImageView * faceImageView = [[UIImageView alloc] init];
    faceImageView.image = [UIImage imageNamed:@"ios_icon.png"];
    faceImageView.backgroundColor = [UIColor greenColor];
    faceImageView.translatesAutoresizingMaskIntoConstraints = false;
    
    // TODO: Create a container view to better position elements.
    [scrollView addSubview:selectImageButton];
    [scrollView addSubview:faceImageView];
    
    NSDictionary * viewsDict = NSDictionaryOfVariableBindings(selectImageButton, faceImageView);
    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[selectImageButton(<=40)]-10-[faceImageView(==200)]-|"
                                                                      options:NSLayoutFormatDirectionLeadingToTrailing
                                                                      metrics:nil
                                                                        views:viewsDict]];
    
    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[selectImageButton(==200)]"
                                                                      options:NSLayoutFormatDirectionLeadingToTrailing
                                                                      metrics:nil
                                                                        views:viewsDict]];

    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[faceImageView(==200)]"
                                                                      options:NSLayoutFormatDirectionLeadingToTrailing
                                                                      metrics:nil
                                                                        views:viewsDict]];

    
    
    [backgroundView addSubview:scrollView];
    
    
    self.view = backgroundView;
}

-(UIToolbar *) buildToolbar
{
    // Progress view.
    self.indexerProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.indexerProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Progress Label (percentage complete).
    m_progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
    UIBarButtonItem * progressLabelItem = [[UIBarButtonItem alloc] initWithCustomView:m_progressLabel];
    
    // Disable or enable indexing.
    self.toggle = [[UISwitch alloc] init];
    [self.toggle addTarget:self action:@selector(toggleIndexing:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem * progressItem = [[UIBarButtonItem alloc] initWithCustomView:self.indexerProgressView];
    UIBarButtonItem * toggleItem = [[UIBarButtonItem alloc] initWithCustomView:self.toggle];
    
    CGFloat width = self.parentViewController.view.frame.size.width;
    UIToolbar * toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, 70)];
    //toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    toolbar.items = @[progressItem, progressLabelItem, toggleItem ];
    
    return toolbar;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.indexerProgressView.progress = 0;
    m_progressLabel.text = @"0 %";
}

-(void)viewDidAppear:(BOOL)animated
{
    self.toggle.on = [self.delegate indexingEnabled];
}

-(void)viewDidDisappear:(BOOL)animated
{
    
}

-(void)onSelectImage:(UIEvent *)buttonEvent
{
    NSLog(@"onSelectImage! %@", buttonEvent);
    [self presentViewController:self.faceCaptureController animated:YES completion:nil];
}

-(void)toggleIndexing:(UIEvent *)obj
{
    [self.delegate enableIndexing:self.toggle.isOn];
}

-(void)progressUpdated:(CGFloat)progress filteredImage:(UIImage *)filteredImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSLog(@"FirstViewController: progressUpdated to %f retain count: %ld", progress, filteredImage.CGImage ? CFGetRetainCount(filteredImage.CGImage) : 0);
        
        if ( filteredImage ) {
            //self.previewImage.image = filteredImage;
        }
        
        self.indexerProgressView.progress = progress;
        m_progressLabel.text = [NSString stringWithFormat:@"%.0f %%", progress * 100];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
