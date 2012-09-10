//
//  OClusterMapView_SampleViewController.m
//  OClusterMapView+Sample
//
//  Created by Botond Kis on 25.09.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "OClusterMapView_SampleViewController.h"
#import "OCAnnotation.h"
#import <math.h>

#define ARC4RANDOM_MAX 0x100000000
#define kTYPE1 @"Banana"
#define kTYPE2 @"Orange"
#define kDEFAULTCLUSTERSIZE 0.2

#define ZOOM_OUT_THRESHOLD 1.1
#define ZOOM_IN_THRESHOLD 1.5
#define PAN_THRESHOLD 0.75

@implementation OClusterMapView_SampleViewController

@synthesize mapView;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    mapView.delegate = self;
    mapView.clusterSize = kDEFAULTCLUSTERSIZE;
    labelNumberOfAnnotations.text = @"Number of Annotations: 0";
}

- (void)viewDidUnload
{
    [self setMapView:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

// ==============================
#pragma mark - UI actions

- (IBAction)removeButtonTouchUpInside:(id)sender {
    [mapView removeAnnotations:mapView.annotations];
    [mapView removeOverlays:mapView.overlays];
    labelNumberOfAnnotations.text = @"Number of Annotations: 0";
}

- (IBAction)addButtonTouchUpInside:(id)sender {
    [mapView removeOverlays:mapView.overlays];
    NSArray *randomLocations = [[NSArray alloc] initWithArray:[self randomCoordinatesGenerator:100]];
    NSMutableSet *annotationsToAdd = [[NSMutableSet alloc] init];
    
    for (CLLocation *loc in randomLocations) {
        
        OCAnnotation *annotation = [[OCAnnotation alloc] initWithPost:[self createRandomPostWithCoordinate:loc.coordinate] latitude:[NSNumber numberWithDouble:loc.coordinate.latitude] longitude:[NSNumber numberWithDouble:loc.coordinate.longitude]];
        [annotationsToAdd addObject:annotation];
        
    }
    
    [mapView addAnnotations:[annotationsToAdd allObjects]];
    labelNumberOfAnnotations.text = [NSString stringWithFormat:@"Number of Annotations: %d", [mapView.annotations count]];
    
    // clean
}

- (IBAction)clusteringButtonTouchUpInside:(UIButton *)sender {
    [mapView removeOverlays:mapView.overlays];
    if (mapView.clusteringEnabled) {
        [sender setTitle:@"turn clustering on" forState:UIControlStateNormal];
        [sender setTitle:@"turn clustering on" forState:UIControlStateSelected];
        [sender setTitle:@"turn clustering on" forState:UIControlStateHighlighted];
        mapView.clusteringEnabled = NO;
    }
    else{
        [sender setTitle:@"turn clustering off" forState:UIControlStateNormal];
        [sender setTitle:@"turn clustering off" forState:UIControlStateSelected];
        [sender setTitle:@"turn clustering off" forState:UIControlStateHighlighted];
        mapView.clusteringEnabled = YES;
    }
}

- (IBAction)addOneButtonTouchupInside:(id)sender {
    [mapView removeOverlays:mapView.overlays];
    NSArray *randomLocations = [[NSArray alloc] initWithArray:[self randomCoordinatesGenerator:1]];
    CLLocationCoordinate2D loc = ((CLLocation *)[randomLocations objectAtIndex:0]).coordinate;
    OCAnnotation *annotation = [[OCAnnotation alloc] initWithPost:[self createRandomPostWithCoordinate:loc] latitude:[NSNumber numberWithDouble:loc.latitude] longitude:[NSNumber numberWithDouble:loc.longitude]];
    
    [mapView addAnnotation:annotation];
    labelNumberOfAnnotations.text = [NSString stringWithFormat:@"Number of Annotations: %d", [mapView.annotations count]];
    
    // clean
}

- (IBAction)changeClusterMethodButtonTouchUpInside:(UIButton *)sender {    
    [mapView removeOverlays:mapView.overlays];
    if (mapView.clusteringMethod == OCClusteringMethodBubble) {
        [sender setTitle:@"Bubble cluster" forState:UIControlStateNormal];
        [sender setTitle:@"Bubble cluster" forState:UIControlStateSelected];
        [sender setTitle:@"Bubble cluster" forState:UIControlStateHighlighted];
        mapView.clusteringMethod = OCClusteringMethodGrid;
    }
    else{
        [sender setTitle:@"Grid cluster" forState:UIControlStateNormal];
        [sender setTitle:@"Grid cluster" forState:UIControlStateSelected];
        [sender setTitle:@"Grid cluster" forState:UIControlStateHighlighted];
        mapView.clusteringMethod = OCClusteringMethodBubble;
    }
    [mapView doClustering];
}

- (IBAction)infoButtonTouchUpInside:(UIButton *)sender{
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Info" message:@"The size of a cluster-annotation represents the number of annotations it contains and not its size." delegate:nil cancelButtonTitle:@"great!" otherButtonTitles:nil];
    [a show];
}

- (IBAction)buttonGroupByTagTouchUpInside:(UIButton *)sender {
    mapView.clusterByGroupTag = ! mapView.clusterByGroupTag;
    if(mapView.clusterByGroupTag){
        [sender setTitle:@"turn groups off" forState:UIControlStateNormal];
        mapView.clusterSize = kDEFAULTCLUSTERSIZE * 2.0;
    }
    else{
        [sender setTitle:@"turn groups on" forState:UIControlStateNormal];
        mapView.clusterSize = kDEFAULTCLUSTERSIZE;
    }
    
    [mapView removeOverlays:mapView.overlays];
    [mapView doClustering];
}

// ==============================
#pragma mark - map delegate
- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id <MKAnnotation>)annotation{
    // if it's the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    if ([annotation isKindOfClass:[OCAnnotation class]])
    {
        OCAnnotation *mapListingAnnotation = (OCAnnotation*)annotation;
        
        NSDictionary *post = mapListingAnnotation.post;
        // if an existing pin view was not available, create one
        OCAnnotationView* customPinView = (OCAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
        
        NSString *smallImageURI = [[post objectForKey:@"image-uri"] stringByAppendingFormat:@"?w=%.0f&h=%.0f", [[UIScreen mainScreen] scale] * 32, [[UIScreen mainScreen] scale] * 32];
        
        if (customPinView==nil) {
            customPinView = [[OCAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
            UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            [rightButton addTarget:self
                            action:@selector(showDetails:)
                  forControlEvents:UIControlEventTouchUpInside];
            customPinView.rightCalloutAccessoryView = rightButton;
            customPinView.canShowCallout = YES;
         }
        
        
            customPinView.image = [UIImage imageNamed:@"banana.png"];
        
        return customPinView;
        
    } else if ([annotation isKindOfClass:[OCClusteredAnnotation class]]) {
        OCClusteredAnnotation *clusterAnnotation = (OCClusteredAnnotation*)annotation;
        OCAnnotation *mapListingAnnotation = (OCAnnotation*)[clusterAnnotation.annotationsInCluster objectAtIndex:0];
        if ([mapListingAnnotation isKindOfClass:[MKUserLocation class]] && [clusterAnnotation.annotationsInCluster count]>1) {
            mapListingAnnotation = [clusterAnnotation.annotationsInCluster objectAtIndex:1];
        }
        NSDictionary *item = mapListingAnnotation.post;
        NSString *title = [item objectForKey:@"location-name"];
        NSString *numberOfItemsSubtitle = [NSString stringWithFormat:@"Number of Items: %d", [clusterAnnotation.annotationsInCluster count]];
        
        [clusterAnnotation setTitle:title];
        [clusterAnnotation setSubtitle:numberOfItemsSubtitle];
        
        OCAnnotationView* customPinView = (OCAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
        
        if (customPinView==nil) {
            customPinView = [[OCAnnotationView alloc] initWithAnnotation:clusterAnnotation reuseIdentifier:@"cluster"];
            customPinView.canShowCallout = YES;
                UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
                [rightButton addTarget:self
                                action:@selector(showDetails:)
                      forControlEvents:UIControlEventTouchUpInside];
                customPinView.rightCalloutAccessoryView = rightButton;
        }
        
        customPinView.image = [UIImage imageNamed:@"bananas.png"];

       
        return customPinView;
    }
    return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay{
    MKCircle *circle = overlay;
    MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:overlay];
    
    if ([circle.title isEqualToString:@"background"])
    {
        circleView.fillColor = [UIColor yellowColor];
        circleView.alpha = 0.25;
    }
    else if ([circle.title isEqualToString:@"helper"])
    {
        circleView.fillColor = [UIColor redColor];
        circleView.alpha = 0.25;
    }
    else
    {
        circleView.strokeColor = [UIColor blackColor];
        circleView.lineWidth = 0.5;
    }
    
    return circleView;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self softUpdateMapView:mapView];
}

- (void) softUpdateMapView:(OCMapView*)mapView {
    CGPoint center = mapView.center;
    CGPoint side = CGPointMake(0, 0);
    
    CLLocationCoordinate2D centerCoordinate = [mapView convertPoint:center toCoordinateFromView:mapView];
    CLLocationCoordinate2D sideCoordinate = [mapView convertPoint:side toCoordinateFromView:mapView];
    
    CLLocation *centerLocation = [[CLLocation alloc] initWithLatitude:centerCoordinate.latitude longitude:centerCoordinate.longitude];
    CLLocation *sideLocation = [[CLLocation alloc] initWithLatitude:sideCoordinate.latitude longitude:sideCoordinate.longitude];
    CLLocation *temporaryCenterLocation = [[CLLocation alloc] initWithLatitude:temporaryCenterCoordinate.latitude longitude:temporaryCenterCoordinate.longitude];
    CLLocation *temporarySideLocation = [[CLLocation alloc] initWithLatitude:temporarySideCoordinate.latitude longitude:temporarySideCoordinate.longitude];
    
    CLLocationCoordinate2D tempSide = temporarySideCoordinate;
    CLLocationCoordinate2D tempCenter = temporaryCenterCoordinate;
    
    BOOL zoomIn = NO;
    BOOL zoomOut = NO;
    BOOL panned = NO;
    if (temporaryCenterCoordinate.latitude == 0 || temporaryCenterCoordinate.longitude == 0 || temporarySideCoordinate.latitude == 0 || temporarySideCoordinate.longitude == 0) {
        temporaryCenterCoordinate = centerCoordinate;
        temporarySideCoordinate = sideCoordinate;
    }
    if ([centerLocation distanceFromLocation:sideLocation]/1000 > ZOOM_OUT_THRESHOLD*[temporaryCenterLocation distanceFromLocation:temporarySideLocation]/1000) {
        temporaryCenterCoordinate = centerCoordinate;
        temporarySideCoordinate = sideCoordinate;
        zoomOut = YES;
    }
    if ([temporaryCenterLocation distanceFromLocation:temporarySideLocation]/1000 > ZOOM_IN_THRESHOLD*[centerLocation distanceFromLocation:sideLocation]/1000) {
        temporaryCenterCoordinate = centerCoordinate;
        temporarySideCoordinate = sideCoordinate;
        zoomIn = YES;
    }
    if (PAN_THRESHOLD*[temporaryCenterLocation distanceFromLocation:temporarySideLocation]/1000 < [temporaryCenterLocation distanceFromLocation:centerLocation]/1000) {
        temporaryCenterCoordinate = centerCoordinate;
        temporarySideCoordinate = sideCoordinate;
        panned = YES;
    }
    
    if (zoomIn==FALSE) {
        if (zoomOut||panned) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [mapView doClusteringZoomOut];
            });
            zoomIn = NO;
            panned = NO;
        }
    }
    
    CLLocationDegrees latDelta = mapView.region.span.latitudeDelta;
    CLLocationDegrees longDelta = mapView.region.span.longitudeDelta;
    CLLocationDegrees latCenter = mapView.region.center.latitude;
    CLLocationDegrees longCenter = mapView.region.center.longitude;
    
    double delayInSeconds = 0.3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (mapView.region.span.latitudeDelta == latDelta &&
            longDelta == mapView.region.span.longitudeDelta &&
            latCenter == mapView.region.center.latitude &&
            longCenter == mapView.region.center.longitude) {
            if (zoomIn||panned) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [mapView doClusteringZoomIn];
                });
            }
        } else {
            temporarySideCoordinate = tempSide;
            temporaryCenterCoordinate = tempCenter;
        }
    });
}

// ==============================
#pragma mark - logic

//
// Help method which returns an array of random CLLocations
// You can specify the number of coordinates by setting numberOfCoordinates
- (NSArray *)randomCoordinatesGenerator:(int) numberOfCoordinates{
    
    numberOfCoordinates = (numberOfCoordinates < 0) ? 0 : numberOfCoordinates;
    
    NSMutableArray *coordinates = [[NSMutableArray alloc] initWithCapacity:numberOfCoordinates];
    for (int i = 0; i < numberOfCoordinates; i++) {
        
        // Get random coordinates
        CLLocationDistance latitude = ((float)arc4random() / ARC4RANDOM_MAX) * 1.0f + 51.0f;    // the latitude goes from +90° - 0 - -90°
        CLLocationDistance longitude = ((float)arc4random() / ARC4RANDOM_MAX) * 1.0f - 0.5f;  // the longitude goes from +180° - 0 - -180°
        
        // This is a fix, because the randomizing above can fail
        latitude = MIN(90.0, latitude);
        latitude = MAX(-90.0, latitude);
        
        longitude = MIN(180.0, longitude);
        longitude = MAX(-180.0, longitude);
        
        
        CLLocation *loc = [[CLLocation alloc]initWithLatitude:latitude longitude:longitude];
        [coordinates addObject:loc];
    }
    return  coordinates;
}

//description = "This is a Banana";
//"geo-location" =     {
//    lat = "51.035260";
//    lon = "-0.285737";
//};
//"location-name" = Random;

- (NSDictionary *) createRandomPostWithCoordinate:(CLLocationCoordinate2D)coordinate {
    NSMutableDictionary *randomPost = [NSMutableDictionary dictionary];
    NSMutableDictionary *location = [NSMutableDictionary dictionary];
    [location setObject:[NSNumber numberWithDouble:coordinate.latitude] forKey:@"lat"];
    [location setObject:[NSNumber numberWithDouble:coordinate.longitude] forKey:@"lon"];
    
    [randomPost setObject:@"This is a Banana" forKey:@"description"];
    [randomPost setObject:@"<Location-Name>" forKey:@"location-name"];
    
    return randomPost;
}


- (void) showDetails:(id)sender {
    
}

@end
