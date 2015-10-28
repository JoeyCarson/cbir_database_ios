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

-(void)viewDidDisappear:(BOOL)animated
{
    if ( m_indexer ) {
        [m_indexer pause];
    }
}

-(void)startIndexing
{
    if ( !m_indexer ) {
        m_indexer = [[PhotoIndexer alloc] initWithDelegate:self];
        self.indexerProgressView.progress = 0;
        [m_indexer fetchAndIndexAssetsWithOptions:nil delegate:self];
    } else {
        [m_indexer resume];
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
