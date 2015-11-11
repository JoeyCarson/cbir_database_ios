//
//  TargetRectangleView.m
//  CBIRD
//
//  Created by Joseph Carson on 11/9/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "TargetRectangleView.h"

@implementation TargetRectangleView


-(instancetype) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if ( self ) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clearsContextBeforeDrawing = NO;
    }
    
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    UIBezierPath * path = [UIBezierPath bezierPathWithRect:rect];
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor clearColor] setFill];
    
    CGContextClearRect(ctx, rect);
    
    [self.rectColor setStroke];
    path.lineWidth = 5.0;
    [path stroke];
}

@end
