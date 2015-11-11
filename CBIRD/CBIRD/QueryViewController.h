//
//  QueryViewController.h
//  CBIRD
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CBIRDatabase/CBIRDatabase.h>
#import "PhotoIndexer.h"

@protocol QueryViewDelegate

- (void)enableIndexing:(BOOL)enabled;
- (BOOL)indexingEnabled;

@end


@interface QueryViewController : UIViewController<PhotoIndexerDelegate, CBIRQueryDelegate>

@property (nonatomic, weak) id<QueryViewDelegate> delegate;
@property (nonatomic) UIProgressView *indexerProgressView;
@property (nonatomic) UISwitch *toggle;

@end

