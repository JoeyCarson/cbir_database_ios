//
//  TargetRectangleView.m
//  CBIRD
//
//  Created by Joseph Carson on 11/9/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "TargetRectangleView.h"

@implementation TargetRectangleView


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {

    [self.rectColor setStroke];
    
    //CGRect pathRect = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    UIBezierPath * path = [UIBezierPath bezierPathWithRect:rect];
    path.lineWidth = 5.0;
    
    [path stroke];
}

@end
