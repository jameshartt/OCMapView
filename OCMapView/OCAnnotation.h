//
//  OCClusteredAnnotation.h
//  needz
//
//  Created by James Hartt on 25/05/2012.
//  Copyright (c) 2012 Ocasta Labs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OCClusteredAnnotation.h"

@interface OCAnnotation : NSObject<MKAnnotation>
{
    NSNumber *latitude;
    NSNumber *longitude;
    NSString *listingTitle;
    NSString *listingSubtitle;
}

@property (nonatomic, strong) NSNumber *latitude;
@property (nonatomic, strong) NSNumber *longitude;
@property (nonatomic, strong) NSString *listingTitle;
@property (nonatomic, strong) NSString *listingSubtitle;
@property (nonatomic, strong) NSDictionary *post;
@property (nonatomic, unsafe_unretained) MKMapView *mapView;
@property (nonatomic, strong) UIImageView *animationImageView;

- (id)initWithPost:(NSDictionary *)thePost latitude:(NSNumber *)theLatitude longitude:(NSNumber *)theLongitude;

@end
