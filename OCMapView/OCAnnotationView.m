//
//  OCAnnotationView.m
//  needz
//
//  Created by James Hartt on 07/05/2012.
//  Copyright (c) 2012 Ocasta Labs. All rights reserved.
//

#import "OCAnnotationView.h"
#import "OCClusteredAnnotation.h"
#import "OCMapView.h"
#import <QuartzCore/QuartzCore.h>
#import "OCAnnotation.h"

@implementation OCAnnotationView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.centerOffset = CGPointMake(7, -15);
    }
    return self;
}

- (void)didMoveToSuperview {
    if ([(OCClusteredAnnotation*)self.annotation animationImageView]) {
        self.hidden = YES;
        [super didMoveToSuperview];
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.hidden = NO;
            [[(OCClusteredAnnotation*)self.annotation animationImageView] removeFromSuperview];
            [(OCClusteredAnnotation*)self.annotation setAnimationImageView:nil];
        });
    } else {
        [super didMoveToSuperview];
    }
}

@end
