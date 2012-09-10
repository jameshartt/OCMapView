//
//  OCMapView.m
//  openClusterMapView
//
//  Created by Botond Kis on 14.07.11.
//

#define VERTICAL_OFFSET_ANIMATION_VIEW -15.5
#define HORIZONTAL_OFFSET_ANIMATION_VIEW 6.5
#define NON_CLUSTER_EXTRA_HORIZONTAL_OFFSET 5

#import "OCMapView.h"
#import "OCAnnotation.h"

@interface OCMapView () {
    UIView *viewToAnimateIn;
    NSPredicate *clustersPredicate;
    NSPredicate *notClustersPredicate;
}
- (void)initSetUp;
@end

@implementation OCMapView
@synthesize clusteringEnabled;
@synthesize annotationsToIgnore;
@synthesize clusteringMethod;
@synthesize clusterSize;
@synthesize clusterByGroupTag;
@synthesize minLongitudeDeltaToCluster;

- (id)init
{
    self = [super init];
    if (self) {
        // call actual initializer
        [self initSetUp];
    }
    
    return self;
}

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        // call actual initializer
        [self initSetUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];    
    if (self) {
        // call actual initializer
        [self initSetUp];
    }
    return self;
}

- (void)initSetUp{
    allAnnotations = [[NSMutableSet alloc] init];
    annotationsToIgnore = [[NSMutableSet alloc] init];
    clusteringMethod = OCClusteringMethodBubble;
    clusterSize = 0.2;
    minLongitudeDeltaToCluster = 0.0;
    clusteringEnabled = YES;
    clusterByGroupTag = NO;
    backgroundClusterQueue = dispatch_queue_create("com.OCMapView.clustering", NULL); 
    clustersPredicate = [NSPredicate predicateWithFormat: @"self isMemberOfClass: %@", [OCClusteredAnnotation class]];
    notClustersPredicate = [NSPredicate predicateWithFormat:@"self isMemberOfClass: %@", [OCAnnotation class]];
}

- (void)dealloc{
    dispatch_release(backgroundClusterQueue);
}

// ======================================
#pragma mark MKMapView implementation

- (void)addAnnotation:(id < MKAnnotation >)annotation{
    [allAnnotations addObject:annotation];
}

- (void)addAnnotations:(NSArray *)annotations{
    [allAnnotations addObjectsFromArray:annotations];
}

- (void)removeAnnotation:(id < MKAnnotation >)annotation{
    [allAnnotations removeObject:annotation];
}

- (void)removeAnnotations:(NSArray *)annotations{
    for (id<MKAnnotation> annotation in annotations) {
        [allAnnotations removeObject:annotation];
    }
}


// ======================================
#pragma mark - Properties
//
// Returns, like the original method,
// all annotations in the map unclustered.
- (NSArray *)annotations{
    return [allAnnotations allObjects];
}

//
// Returns all annotations which are actually displayed on the map. (clusters)
- (NSArray *)displayedAnnotations{
    return super.annotations;    
}

//
// enable or disable clustering
- (void)setClusteringEnabled:(BOOL)enabled{
    clusteringEnabled = enabled;
    [self doClusteringZoomOut];
}

// ======================================
#pragma mark - Clustering

- (void)doClusteringZoomIn {
    //[MMStopwatchARC start:@"doClusteringZoomIn"];
    self.zoomEnabled = NO;

    viewToAnimateIn = [self annotationViewToDoAnimations];
    
    // Remove the annotation which should be ignored
    NSMutableArray *bufferArray = [[NSMutableArray alloc] initWithArray:[allAnnotations allObjects]];
    [bufferArray removeObjectsInArray:[annotationsToIgnore allObjects]];
    NSMutableArray *annotationsToCluster = [[NSMutableArray alloc] initWithArray:[self filterAnnotationsForVisibleMap:bufferArray]];
    [annotationsToCluster removeObject:self.userLocation];
    
    NSArray *visibleAnnotations = [self filterAnnotationsForVisibleMap:self.displayedAnnotations];
    NSArray *alreadyClusteredAnnotations = [visibleAnnotations filteredArrayUsingPredicate:clustersPredicate];
    
    //calculate cluster radius
    CLLocationDistance clusterRadius = self.region.span.longitudeDelta * clusterSize;
    
    // Do clustering
    NSMutableArray *clusteredAnnotations;
    
    // Check if clustering is enabled and map is above the minZoom
    if (clusteringEnabled && (self.region.span.longitudeDelta > minLongitudeDeltaToCluster)) {
        
        // switch to selected algoritm
        switch (clusteringMethod) {
            case OCClusteringMethodBubble:{
                clusteredAnnotations = [[NSMutableArray alloc] initWithArray:[OCAlgorithms bubbleClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRadius:clusterRadius grouped:self.clusterByGroupTag]];
                break;
            }
            case OCClusteringMethodGrid:{
                clusteredAnnotations =[[NSMutableArray alloc] initWithArray:[OCAlgorithms gridClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRect:MKCoordinateSpanMake(clusterRadius, clusterRadius)  grouped:self.clusterByGroupTag]];
                break;
            }
            default:{
                clusteredAnnotations = annotationsToCluster;
                break;
            }
        }
    }
    // pass through without when not
    else{
        clusteredAnnotations = annotationsToCluster;
    }
    
    
    NSArray *notClusters = [clusteredAnnotations filteredArrayUsingPredicate:notClustersPredicate];
    
    NSMutableSet *animationAnnotations = [NSMutableSet set];
    
    for (OCClusteredAnnotation *annotation in notClusters) {
        //NSLog(@"DID NOT CLUSTER!");
        OCAnnotation *listingMapAnnotation = (OCAnnotation*)annotation;
        
        //NSLog(@"DID ALREADY EXIST:%@", [visibleAnnotations indexOfObject:listingMapAnnotation] != NSNotFound ? @"YES" : @"NO");
        if ([visibleAnnotations indexOfObject:listingMapAnnotation] != NSNotFound) {
        } else {
            for (id<MKAnnotation>annotation in alreadyClusteredAnnotations) {
                OCClusteredAnnotation *groupedAnnotation = (OCClusteredAnnotation*)annotation;
                if ([groupedAnnotation.annotationsInCluster indexOfObject:listingMapAnnotation] != NSNotFound) {
                    UIImage *annotationImage = [UIImage imageNamed:@"banana.png"];
                    UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, annotationImage.size.width, annotationImage.size.height)];
                    annotationView.image = annotationImage;
                    
                    
                    CGPoint pointToMoveFrom = [self convertCoordinate:groupedAnnotation.coordinate toPointToView:viewToAnimateIn];
                    CGPoint pointToMoveTo = [self convertCoordinate:listingMapAnnotation.coordinate toPointToView:viewToAnimateIn];
                    
                    [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
                    
                    pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
                    pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW+NON_CLUSTER_EXTRA_HORIZONTAL_OFFSET;
                    pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
                    pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
                    
                    annotationView.center = pointToMoveFrom;
                    
                    listingMapAnnotation.animationImageView = annotationView;
                    
                    [super addAnnotation:listingMapAnnotation];
                    [animationAnnotations addObject:listingMapAnnotation];
                    [UIView animateWithDuration:0.35 animations:^{
                        annotationView.center = pointToMoveTo;
                    } completion:nil];
                    
                }
            }
        }
    }
    
    
    NSArray *clusters = [clusteredAnnotations filteredArrayUsingPredicate:clustersPredicate];
    
    NSMutableArray *oldClusters = [clusters mutableCopy];
    [oldClusters removeObjectsInArray:alreadyClusteredAnnotations];
    for (OCClusteredAnnotation *oldClusteredAnnotation in oldClusters) {
        MKAnnotationView *actualAnnotationView = [self viewForAnnotation:oldClusteredAnnotation];
        if (actualAnnotationView && oldClusteredAnnotation.moveToCoordinate.latitude != 0.0 && oldClusteredAnnotation.moveToCoordinate.longitude != 0.0) {                
            CLLocationCoordinate2D newCoordinate = oldClusteredAnnotation.coordinate;
            CLLocationCoordinate2D alreadyClusteredCoordinate = oldClusteredAnnotation.moveToCoordinate;
            
            UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, actualAnnotationView.image.size.width, actualAnnotationView.image.size.height)];
            annotationView.image = actualAnnotationView.image;
            
            
            CGPoint pointToMoveFrom = [self convertCoordinate:alreadyClusteredCoordinate toPointToView:viewToAnimateIn];
            CGPoint pointToMoveTo = [self convertCoordinate:newCoordinate toPointToView:viewToAnimateIn];
            [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
            [oldClusteredAnnotation setCoordinate:newCoordinate];
            
            pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            
            annotationView.center = pointToMoveFrom;
            oldClusteredAnnotation.animationImageView = annotationView;
            [UIView animateWithDuration:0.35 animations:^{
                annotationView.center = pointToMoveTo;
            } completion:nil];
            
        }
    }
    
    if ([alreadyClusteredAnnotations count]) {
        for (OCClusteredAnnotation *newClusteredAnnotation in oldClusters) {
            CLLocationCoordinate2D newCoordinate = newClusteredAnnotation.coordinate;
            CLLocationCoordinate2D alreadyClusteredCoordinate = [(OCClusteredAnnotation *)[alreadyClusteredAnnotations objectAtIndex:0] coordinate];
            CLLocationDistance lowestDistance = getDistance(newCoordinate, alreadyClusteredCoordinate);
            
            for (OCClusteredAnnotation *alreadyClusteredAnnotation in alreadyClusteredAnnotations) {
                CLLocationDistance newDistanceToTest = getDistance(newCoordinate, alreadyClusteredAnnotation.coordinate);
                if (newDistanceToTest < lowestDistance) {
                    alreadyClusteredCoordinate = alreadyClusteredAnnotation.coordinate;
                    lowestDistance = getDistance(newCoordinate, alreadyClusteredCoordinate);
                }
            }
            
            NSUInteger wanted = 0;
            NSUInteger notWanted = 0;
            for (OCAnnotation *mapListingAnnotation in newClusteredAnnotation.annotationsInCluster) {
                if ([mapListingAnnotation isMemberOfClass:[OCAnnotation class]]) {
                    if ([[mapListingAnnotation.post objectForKey:@"postType"] isEqualToString:@"wanted"]) {
                        wanted++;
                    } else {
                        notWanted++;
                    }
                }
            }
            
            UIImage *annotationImage = [UIImage imageNamed:@"bananas.png"];
            
            
            UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, annotationImage.size.width, annotationImage.size.height)];
            annotationView.image = annotationImage;
            
            CGPoint pointToMoveFrom = [self convertCoordinate:alreadyClusteredCoordinate toPointToView:viewToAnimateIn];
            CGPoint pointToMoveTo = [self convertCoordinate:newCoordinate toPointToView:viewToAnimateIn];
            
            [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
            
            pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            
            annotationView.center = pointToMoveFrom;
            
            newClusteredAnnotation.animationImageView = annotationView;
            [super addAnnotation:newClusteredAnnotation];
            [animationAnnotations addObject:newClusteredAnnotation];
            [UIView animateWithDuration:0.35 animations:^{
                annotationView.center = pointToMoveTo;
            } completion:nil];
            
        }
    }
    
    
    
    // Clear map but leave Userlcoation
    NSMutableArray *annotationsToRemove = [[NSMutableArray alloc] initWithArray:self.displayedAnnotations];
    [annotationsToRemove removeObjectsInArray: clusteredAnnotations];
    [annotationsToRemove removeObject:self.userLocation];
    
    [clusteredAnnotations removeObjectsInArray:[animationAnnotations allObjects]];
    // add clustered and ignored annotations to map    
    [super addAnnotations: clusteredAnnotations];
    
    [super addAnnotations: [annotationsToIgnore allObjects]];
    
    
    for (id<MKAnnotation> annotation in annotationsToRemove) {
        if ([annotation isMemberOfClass:[OCClusteredAnnotation class]]) {
            MKAnnotationView *annotationView = [self viewForAnnotation:annotation];
            [UIView animateWithDuration:0.3 animations:^{
                annotationView.alpha = 0.0;
            } completion:^(BOOL finished) {
                annotationView.alpha = 1.0;
            }];
        }
    }
    [super removeAnnotations:annotationsToRemove];

    self.zoomEnabled = YES;
    //[MMStopwatchARC stop:@"doClusteringZoomIn"];
}

- (void)doClusteringZoomOut {
    //[MMStopwatchARC start:@"doClusteringZoomOut"];
    self.zoomEnabled = NO;
    viewToAnimateIn = [self annotationViewToDoAnimations];

    // Remove the annotation which should be ignored
    NSMutableArray *bufferArray = [[NSMutableArray alloc] initWithArray:[allAnnotations allObjects]];
    [bufferArray removeObjectsInArray:[annotationsToIgnore allObjects]];
    NSMutableArray *annotationsToCluster = [[NSMutableArray alloc] initWithArray:[self filterAnnotationsForVisibleMap:bufferArray]];
    
    //NSLog(@"annotationsToCluster:%@", annotationsToCluster);
    
    NSArray *visibleAnnotations = [self filterAnnotationsForVisibleMap:self.displayedAnnotations];
    NSArray *alreadyClusteredAnnotations = [visibleAnnotations filteredArrayUsingPredicate:clustersPredicate];

    //calculate cluster radius
    CLLocationDistance clusterRadius = self.region.span.longitudeDelta * clusterSize;
    
    // Do clustering
    NSMutableArray *clusteredAnnotations;
    
    // Check if clustering is enabled and map is above the minZoom
    if (clusteringEnabled && (self.region.span.longitudeDelta > minLongitudeDeltaToCluster)) {
        
        // switch to selected algoritm
        switch (clusteringMethod) {
            case OCClusteringMethodBubble:{
                clusteredAnnotations = [[NSMutableArray alloc] initWithArray:[OCAlgorithms bubbleClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRadius:clusterRadius grouped:self.clusterByGroupTag]];
                break;
            }
            case OCClusteringMethodGrid:{
                clusteredAnnotations =[[NSMutableArray alloc] initWithArray:[OCAlgorithms gridClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRect:MKCoordinateSpanMake(clusterRadius, clusterRadius)  grouped:self.clusterByGroupTag]];
                break;
            }
            default:{
                clusteredAnnotations = annotationsToCluster;
                break;
            }
        }
    }
    // pass through without when not
    else{
        clusteredAnnotations = annotationsToCluster;
    }
    
    NSArray *notClusters = [annotationsToCluster filteredArrayUsingPredicate:notClustersPredicate];
        
    NSArray *clusters = [clusteredAnnotations filteredArrayUsingPredicate:clustersPredicate];

    
    for (OCClusteredAnnotation *annotation in notClusters) {
        //NSLog(@"DID NOT CLUSTER!");
        OCAnnotation *listingMapAnnotation = (OCAnnotation*)annotation;
        
        if ([self viewForAnnotation:listingMapAnnotation]) {
            for (id<MKAnnotation>annotation in clusters) {
                OCClusteredAnnotation *groupedAnnotation = (OCClusteredAnnotation*)annotation;
                if ([groupedAnnotation.annotationsInCluster indexOfObject:listingMapAnnotation] != NSNotFound) {
                    UIImage *annotationImage = [UIImage imageNamed:@"banana.png"];
                    UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, annotationImage.size.width, annotationImage.size.height)];
                    annotationView.image = annotationImage;
                    
                    
                    CGPoint pointToMoveFrom = [self convertCoordinate:listingMapAnnotation.coordinate toPointToView:viewToAnimateIn];
                    CGPoint pointToMoveTo = [self convertCoordinate:groupedAnnotation.coordinate toPointToView:viewToAnimateIn];
                    
                    [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
                    
                    pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
                    pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
                    pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
                    pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW+NON_CLUSTER_EXTRA_HORIZONTAL_OFFSET;
                    
                    annotationView.center = pointToMoveFrom;
                    
                    listingMapAnnotation.animationImageView = annotationView;
                    
                    [UIView animateWithDuration:0.35 animations:^{
                        annotationView.center = pointToMoveTo;
                    } completion:^(BOOL finished) {
                        [annotationView removeFromSuperview];
                    }];
                    
                }
            }
        }
    }
    
    
    
    NSMutableArray *oldClusters = [clusters mutableCopy];
    [oldClusters removeObjectsInArray:alreadyClusteredAnnotations];
    for (OCClusteredAnnotation *oldClusteredAnnotation in oldClusters) {
        MKAnnotationView *actualAnnotationView = [self viewForAnnotation:oldClusteredAnnotation];
        if (actualAnnotationView && oldClusteredAnnotation.moveToCoordinate.latitude != 0.0 && oldClusteredAnnotation.moveToCoordinate.longitude != 0.0) {                
            CLLocationCoordinate2D newCoordinate = oldClusteredAnnotation.coordinate;
            CLLocationCoordinate2D alreadyClusteredCoordinate = oldClusteredAnnotation.moveToCoordinate;
            
            UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, actualAnnotationView.image.size.width, actualAnnotationView.image.size.height)];
            annotationView.image = actualAnnotationView.image;
            
            
            CGPoint pointToMoveFrom = [self convertCoordinate:alreadyClusteredCoordinate toPointToView:viewToAnimateIn];
            CGPoint pointToMoveTo = [self convertCoordinate:newCoordinate toPointToView:viewToAnimateIn];
            [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
            [oldClusteredAnnotation setCoordinate:newCoordinate];
            
            pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            
            annotationView.center = pointToMoveFrom;
            oldClusteredAnnotation.animationImageView = annotationView;
            
            [UIView animateWithDuration:0.35 animations:^{
                annotationView.center = pointToMoveTo;
            } completion:nil];
            
        }
    }
    
    NSMutableArray *noLongerExistingClusters = [alreadyClusteredAnnotations mutableCopy];
    [noLongerExistingClusters removeObjectsInArray:clusters];
        
    if ([alreadyClusteredAnnotations count]) {
        for (OCClusteredAnnotation *newClusteredAnnotation in noLongerExistingClusters) {
            CLLocationCoordinate2D newCoordinate = newClusteredAnnotation.coordinate;
            CLLocationCoordinate2D alreadyClusteredCoordinate = newClusteredAnnotation.coordinate;
            
            for (OCClusteredAnnotation *alreadyClusteredAnnotation in clusters) {
                if ([alreadyClusteredAnnotation.annotationsInCluster indexOfObject:[newClusteredAnnotation.annotationsInCluster lastObject]] != NSNotFound) {
                    alreadyClusteredCoordinate = alreadyClusteredAnnotation.coordinate;
                    break;
                }
            }
            
            NSUInteger wanted = 0;
            NSUInteger notWanted = 0;
            for (OCAnnotation *mapListingAnnotation in newClusteredAnnotation.annotationsInCluster) {
                if ([mapListingAnnotation isMemberOfClass:[OCAnnotation class]]) {
                    if ([[mapListingAnnotation.post objectForKey:@"postType"] isEqualToString:@"wanted"]) {
                        wanted++;
                    } else {
                        notWanted++;
                    }
                }
            }
            

            UIImage *annotationImage = [UIImage imageNamed:@"bananas.png"];
            
            
            UIImageView *annotationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, annotationImage.size.width, annotationImage.size.height)];
            annotationView.image = annotationImage;
            
            CGPoint pointToMoveFrom = [self convertCoordinate:newCoordinate toPointToView:viewToAnimateIn];
            CGPoint pointToMoveTo = [self convertCoordinate:alreadyClusteredCoordinate toPointToView:viewToAnimateIn];
            
            [viewToAnimateIn insertSubview:annotationView atIndex:[[viewToAnimateIn subviews] count]-1];
            
            pointToMoveFrom.y = round(pointToMoveFrom.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveFrom.x = round(pointToMoveFrom.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.y = round(pointToMoveTo.y)+VERTICAL_OFFSET_ANIMATION_VIEW;
            pointToMoveTo.x = round(pointToMoveTo.x)+HORIZONTAL_OFFSET_ANIMATION_VIEW;
            
            annotationView.center = pointToMoveFrom;
            
            [UIView animateWithDuration:0.35 animations:^{
                annotationView.center = pointToMoveTo;
            } completion:^(BOOL finished) {
                [annotationView removeFromSuperview];
            }];
            
        }
    }
    
    // Clear map but leave Userlcoation
    NSMutableArray *annotationsToRemove = [[NSMutableArray alloc] initWithArray:self.displayedAnnotations];
    [annotationsToRemove removeObject:self.userLocation];

    [super addAnnotations: clusteredAnnotations];
    // add ignored annotations
    [super addAnnotations: [annotationsToIgnore allObjects]];
    
    // fix for flickering
    [annotationsToRemove removeObjectsInArray: clusteredAnnotations];
    
    [super removeAnnotations:annotationsToRemove];
    
    self.zoomEnabled = YES;
    //[MMStopwatchARC stop:@"doClusteringZoomOut"];
}

- (void)doClustering{
    
    self.zoomEnabled = NO;
    // Remove the annotation which should be ignored
    NSMutableArray *bufferArray = [[NSMutableArray alloc] initWithArray:[allAnnotations allObjects]];
    [bufferArray removeObjectsInArray:[annotationsToIgnore allObjects]];
    NSMutableArray *annotationsToCluster = [[NSMutableArray alloc] initWithArray:[self filterAnnotationsForVisibleMap:bufferArray]];
    
    //NSLog(@"annotationsToCluster:%@", annotationsToCluster);
    
    NSArray *visibleAnnotations = [self filterAnnotationsForVisibleMap:self.displayedAnnotations];
    NSArray *alreadyClusteredAnnotations = [visibleAnnotations filteredArrayUsingPredicate:clustersPredicate];
    
    //calculate cluster radius
    CLLocationDistance clusterRadius = self.region.span.longitudeDelta * clusterSize;
    
    // Do clustering
    NSMutableArray *clusteredAnnotations;
    
    // Check if clustering is enabled and map is above the minZoom
    if (clusteringEnabled && (self.region.span.longitudeDelta > minLongitudeDeltaToCluster)) {
        
        // switch to selected algoritm
        switch (clusteringMethod) {
            case OCClusteringMethodBubble:{
                clusteredAnnotations = [[NSMutableArray alloc] initWithArray:[OCAlgorithms bubbleClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRadius:clusterRadius grouped:self.clusterByGroupTag]];
                break;
            }
            case OCClusteringMethodGrid:{
                clusteredAnnotations =[[NSMutableArray alloc] initWithArray:[OCAlgorithms gridClusteringWithAnnotations:annotationsToCluster alreadyClusteredAnnotations:alreadyClusteredAnnotations andClusterRect:MKCoordinateSpanMake(clusterRadius, clusterRadius)  grouped:self.clusterByGroupTag]];
                break;
            }
            default:{
                clusteredAnnotations = annotationsToCluster;
                break;
            }
        }
    }
    // pass through without when not
    else{
        clusteredAnnotations = annotationsToCluster;
    }
    
    // Clear map but leave Userlcoation
    NSMutableArray *annotationsToRemove = [[NSMutableArray alloc] initWithArray:self.displayedAnnotations];
    [annotationsToRemove removeObject:self.userLocation];
    
    [super addAnnotations: clusteredAnnotations];
    // add ignored annotations
    [super addAnnotations: [annotationsToIgnore allObjects]];
    
    // fix for flickering
    [annotationsToRemove removeObjectsInArray: clusteredAnnotations];

    [super removeAnnotations:annotationsToRemove];
    
    self.zoomEnabled = YES;
}


// ======================================
#pragma mark - Helpers

- (NSArray *)filterAnnotationsForVisibleMap:(NSArray *)annotationsToFilter{
    // return array
    NSMutableArray *filteredAnnotations = [[NSMutableArray alloc] initWithCapacity:[annotationsToFilter count]];
    
    // border calculation
    CLLocationDistance a = self.region.span.latitudeDelta/2.0;
    CLLocationDistance b = self.region.span.longitudeDelta /2.0;
    CLLocationDistance radius = sqrt(a*a + b*b);
    
    for (id<MKAnnotation> annotation in annotationsToFilter) {
        // if annotation is not inside the coordinates, kick it
        if (isLocationNearToOtherLocation(annotation.coordinate, self.centerCoordinate, radius*1.5)) {
            [filteredAnnotations addObject:annotation];
        }
    }
    
    return filteredAnnotations;
}

- (UIView*) annotationViewToDoAnimations {
    if (viewToAnimateIn) {
        return viewToAnimateIn;
    }
    for (UIView *subview in self.subviews) {
        if ([subview isMemberOfClass:[UIView class]]) {
            for (UIView *subsubview in subview.subviews) {
                if ([subsubview isMemberOfClass:NSClassFromString(@"MKScrollView")]) {
                    for (UIView *subsubsubview in subsubview.subviews) {
                        if ([subsubsubview isKindOfClass:NSClassFromString(@"MKAnnotationContainerView")]) {
                            viewToAnimateIn = subsubsubview;
                            return subsubsubview;
                        }
                    }
                }
            }
        }
    }
    return self;
}

@end
