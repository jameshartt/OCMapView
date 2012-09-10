//
//  OCAnnotation.m
//  needz
//
//  Created by James Hartt on 25/05/2012.
//  Copyright (c) 2012 Ocasta Labs. All rights reserved.
//

#import "OCAnnotation.h"

@implementation OCAnnotation

@synthesize latitude, longitude, listingTitle, listingSubtitle, post, mapView, animationImageView;

- (id)initWithPost:(NSDictionary *)thePost latitude:(NSNumber *)theLatitude longitude:(NSNumber *)theLongitude 
{
    self = [super init];
    if (self) {
        self.latitude = theLatitude;
        self.longitude = theLongitude;
        self.post = thePost;
    }
    return self;
}

- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D theCoordinate;
    theCoordinate.latitude = (CLLocationDegrees)[self.latitude doubleValue];
    theCoordinate.longitude = (CLLocationDegrees)[self.longitude doubleValue];
    return theCoordinate; 
}

- (void) setCoordinate:(CLLocationCoordinate2D)coord {
    self.latitude = [NSNumber numberWithDouble:coord.latitude];
    self.longitude = [NSNumber numberWithDouble:coord.longitude];
}

- (NSString *)title {
    return (self.listingTitle != nil) ? self.listingTitle : nil;
}

// optional
- (NSString *)subtitle {
    return (self.listingSubtitle != nil) ? self.listingSubtitle : nil;
}

@end
