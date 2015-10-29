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
    PhotoIndexer * m_indexer;
}

@property (weak, nonatomic) IBOutlet UIProgressView *indexerProgressView;
@property (weak, nonatomic) IBOutlet UIImageView *previewImage;
@property (weak, nonatomic) IBOutlet UIButton *toggle;


@end



@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.indexerProgressView.progress = 0;
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(toggleIndexing) userInfo:nil repeats:NO];
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    
}

-(void)toggleIndexing
{
    if ( !m_indexer ) {
        m_indexer = [[PhotoIndexer alloc] initWithDelegate:self];
        [m_indexer fetchAndIndexAssetsWithOptions:nil delegate:self];
    }
    
    
    if ( !m_indexer.isRunning ) {
        [m_indexer resume];
    } else {
        [m_indexer pause];
    }
}

-(void)progressUpdated:(CGFloat)progress filteredImage:(UIImage *)filteredImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSLog(@"FirstViewController: progressUpdated to %f retain count: %ld", progress, filteredImage.CGImage ? CFGetRetainCount(filteredImage.CGImage) : 0);
        
        if ( filteredImage ) {
            self.previewImage.image = filteredImage;
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
