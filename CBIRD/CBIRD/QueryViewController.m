//
//  FirstViewController.m
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "QueryViewController.h"
#import "PhotoIndexer.h"

@interface QueryViewController ()
{
    NSTimer * timer;
    PhotoIndexer * m_indexer;
}

@end



@implementation QueryViewController

-(void)loadView
{
    self.indexerProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.indexerProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    self.toggle = [[UISwitch alloc] init];
    self.toggle.on = YES;
    [self.toggle addTarget:self action:@selector(toggleIndexing:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem * progressItem = [[UIBarButtonItem alloc] initWithCustomView:self.indexerProgressView];
    UIBarButtonItem * toggleItem = [[UIBarButtonItem alloc] initWithCustomView:self.toggle];
    
    CGFloat width = self.parentViewController.view.frame.size.width;
    UIToolbar * toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, 70)];
    //toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    toolbar.items = @[progressItem, spacer, toggleItem ];

    UIView * backgroundView = [[UIView alloc] init];
    backgroundView.backgroundColor = [UIColor blackColor];
    [backgroundView addSubview:toolbar];
    
    
    self.view = backgroundView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.indexerProgressView.progress = 0;
    //timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(toggleIndexing:) userInfo:nil repeats:NO];
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    
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
        //self.progressLabel.text = [NSString stringWithFormat:@"%f %%", progress * 100];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
