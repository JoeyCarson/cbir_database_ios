//
//  FirstViewController.m
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "FirstViewController.h"
#import "PhotoIndexer.h"

@interface FirstViewController ()
{
    NSTimer * timer;
}

@property (weak, nonatomic) IBOutlet UIProgressView *indexerProgressView;
@property (weak, nonatomic) IBOutlet UIImageView *previewImage;


@end



@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated
{
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(startIndexing) userInfo:nil repeats:NO];
    self.indexerProgressView.progress = 0;
}

-(void)startIndexing
{
    self.indexerProgressView.progress = 0;
    [PhotoIndexer fetchAndIndexAssetsWithOptions:nil delegate:self];
}

-(void)progressUpdated:(CGFloat)progress filteredImage:(UIImage *)filteredImage
{
    __block CGFloat blockProgress = progress;
    dispatch_async(dispatch_get_main_queue(), ^void() {
        
        
        
        NSLog(@"FirstViewController: progressUpdated to %f retain count: %ld", blockProgress, filteredImage.CGImage ? CFGetRetainCount(filteredImage.CGImage) : 0);
        
        self.previewImage.image = filteredImage;
        self.indexerProgressView.progress = blockProgress;
        //self.progressLabel.text = [NSString stringWithFormat:@"%f %%", progress * 100];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
