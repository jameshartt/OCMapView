//
//  OCMapViewSampleHelpAnnotation.m
//  openClusterMapView
//
//  Created by Botond Kis on 17.07.11.
//

#import "OCMapViewSampleHelpAnnotation.h"

@implementation OCMapViewSampleHelpAnnotation

// memory
- (id)initWithCoordinate:(CLLocationCoordinate2D)aCoordinate
{
    self = [super init];
    if (self) {
        coordinate = aCoordinate;
        title = subtitle = nil;
    }
    
    return self;
}


// Properties
- (NSString *)title{
    return title;
}

- (void)setTitle:(NSString *)text{
    title = text;
}

- (NSString *)subtitle{
    return subtitle;
}

- (void)setSubtitle:(NSString *)text{
    subtitle = text;
}

- (NSString *)groupTag{
    return _groupTag;
}

- (void)setGroupTag:(NSString *)tag{
    _groupTag = tag;
}

- (CLLocationCoordinate2D)coordinate{
    return coordinate;
}

@end
