//
//  OCAlgorythms.m
//  openClusterMapView
//
//  Created by Botond Kis on 15.07.11.
//

#import "OCAlgorithms.h"
#import "OCClusteredAnnotation.h"
#import "OCAnnotation.h"
#import "OCDistance.h"
#import "OCGrouping.h"
#import <math.h>
#include <mach/mach_time.h>
#include <stdint.h>

@implementation OCAlgorithms

#pragma mark - bubbleClustering

// Bubble clustering with iteration
+ (NSArray*) bubbleClusteringWithAnnotations:(NSArray *) annotationsToCluster alreadyClusteredAnnotations:(NSArray*) alreadyClusteredAnnotations andClusterRadius:(CLLocationDistance)radius grouped:(BOOL) grouped{
    
    // return array
    NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    
	// Clustering
	for (id <MKAnnotation> annotation in annotationsToCluster) {
		// flag for cluster
		BOOL isContaining = NO;
		
		// If it's the first one, add it as new cluster annotation
		if([clusteredAnnotations count] == 0){
            //NSLog(@"CREATE NEW FIRST COUNT");
            OCClusteredAnnotation *newCluster = [[OCClusteredAnnotation alloc] initWithAnnotation:annotation];
            [clusteredAnnotations addObject:newCluster];
            
            // check group
            if (grouped && [annotation respondsToSelector:@selector(groupTag)]) {
                newCluster.groupTag = ((id <OCGrouping>)annotation).groupTag;
            }
        }
		else {
            for (OCClusteredAnnotation *clusterAnnotation in clusteredAnnotations) {
                // If the annotation is in range of the Cluster add it to it
                if(isLocationNearToOtherLocation([annotation coordinate], [clusterAnnotation coordinate], radius)){
                    
                    // check group
                    if (grouped && [annotation respondsToSelector:@selector(groupTag)]) {
                        if (![clusterAnnotation.groupTag isEqualToString:((id <OCGrouping>)annotation).groupTag])
                            continue;
                    }
                    
					isContaining = YES;
					[clusterAnnotation addAnnotation:annotation];
					break;
				}
            }
            
            // If the annotation is not in a Cluster make it to a new one
			if (!isContaining){
                //NSLog(@"CREATE NEW NOT FIRST COUNT");
				OCClusteredAnnotation *newCluster = [[OCClusteredAnnotation alloc] initWithAnnotation:annotation];
				[clusteredAnnotations addObject:newCluster];
                
                // check group
                if (grouped && [annotation respondsToSelector:@selector(groupTag)]) {
                    newCluster.groupTag = ((id <OCGrouping>)annotation).groupTag;
                }
            }
		}
	}
    
    // Create array to return
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
    // whipe all empty or single annotations
    for (OCClusteredAnnotation *anAnnotation in clusteredAnnotations) {
        if ([anAnnotation.annotationsInCluster count] <= 2) {
            [returnArray addObjectsFromArray:anAnnotation.annotationsInCluster];
        }
        else{
            [returnArray addObject:anAnnotation];
        }
    }
    
    // Create array for clusters to check with already existing clusters
    NSPredicate *clusterPredicate = [NSPredicate predicateWithFormat:@"self isMemberOfClass: %@",[OCClusteredAnnotation class]];
    
    NSArray *clusters = [returnArray filteredArrayUsingPredicate:clusterPredicate];
    
    for (OCClusteredAnnotation *clusterAnnotation in clusters) {
        CLLocationDegrees averageLat=0;
        CLLocationDegrees averageLong=0;
        NSUInteger count = [[clusterAnnotation annotationsInCluster] count];
        for (id<MKAnnotation> annotation in [clusterAnnotation annotationsInCluster]) {
            averageLat += annotation.coordinate.latitude;
            averageLong += annotation.coordinate.longitude;
        }
        averageLat /= (double)count;
        averageLong /= (double)count;
        for (OCClusteredAnnotation *alreadyClusteredAnnotation in alreadyClusteredAnnotations) {
            if (isLocationNearToOtherLocation(clusterAnnotation.coordinate, alreadyClusteredAnnotation.coordinate, radius/100)) {

                if (!isLocationNearToOtherLocation(alreadyClusteredAnnotation.coordinate, CLLocationCoordinate2DMake(averageLat, averageLong), 0.0005)) {
                    [alreadyClusteredAnnotation setMoveToCoordinate:CLLocationCoordinate2DMake(averageLat, averageLong)];
                } else {
                    [alreadyClusteredAnnotation setMoveToCoordinate:CLLocationCoordinate2DMake(0, 0)];
                }
                NSUInteger replaceIndex = [returnArray indexOfObject:clusterAnnotation];
                if (replaceIndex == NSNotFound || [alreadyClusteredAnnotation isMemberOfClass:[MKUserLocation class]]) {
                    continue;
                }
                [returnArray replaceObjectAtIndex:replaceIndex withObject:alreadyClusteredAnnotation];
                [alreadyClusteredAnnotation setAnnotationsInCluster:[clusterAnnotation annotationsInCluster]];
                NSString *numberOfItemsSubtitle = [NSString stringWithFormat:@"Number of Items:%d", count];
                //[alreadyClusteredAnnotation willChangeValueForKey:@"subtitle"];
                [alreadyClusteredAnnotation setSubtitle:numberOfItemsSubtitle];
                //[alreadyClusteredAnnotation didChangeValueForKey:@"subtitle"];
                NSDictionary *item = [(OCAnnotation*)[alreadyClusteredAnnotation.annotationsInCluster objectAtIndex:rand()%count] post];
                NSString *title = [item objectForKey:@"location-name"];
                //[alreadyClusteredAnnotation willChangeValueForKey:@"title"];
                [alreadyClusteredAnnotation setTitle:title];
                //[alreadyClusteredAnnotation didChangeValueForKey:@"title"];
                break;
            }
        }
        [clusterAnnotation setCoordinate:CLLocationCoordinate2DMake(averageLat, averageLong)];
    }    
    return returnArray;
}


// Grid clustering with predefined size
+ (NSArray*) gridClusteringWithAnnotations:(NSArray *) annotationsToCluster alreadyClusteredAnnotations:(NSArray*)alreadyClusteredAnnotations andClusterRect:(MKCoordinateSpan)tileRect grouped:(BOOL) grouped{
    
    // return array
    NSMutableDictionary *clusteredAnnotations = [[NSMutableDictionary alloc] init];
    
    // iterate through all annotations
	for (id <MKAnnotation> annotation in annotationsToCluster) {
        
        // calculate grid coordinates of the annotation
        int row = ([annotation coordinate].longitude+180.0)/tileRect.longitudeDelta;
        int column = ([annotation coordinate].latitude+90.0)/tileRect.latitudeDelta;
        
        NSString *key = [NSString stringWithFormat:@"%d%d",row,column];
        
        
        // get the cluster for the calculated coordinates
        OCClusteredAnnotation *clusterAnnotation = [clusteredAnnotations objectForKey:key];
        
        // if there is none, create one
        if (clusterAnnotation == nil) {
            clusterAnnotation = [[OCClusteredAnnotation alloc] init];
            
            CLLocationDegrees lon = row * tileRect.longitudeDelta + tileRect.longitudeDelta/2.0 - 180.0;
            CLLocationDegrees lat = (column * tileRect.latitudeDelta) + tileRect.latitudeDelta/2.0 - 90.0;
            clusterAnnotation.coordinate = CLLocationCoordinate2DMake(lat, lon);
            
            // check group
            if (grouped && [annotation respondsToSelector:@selector(groupTag)]) {
                clusterAnnotation.groupTag = ((id <OCGrouping>)annotation).groupTag;
            }
            
            [clusteredAnnotations setValue:clusterAnnotation forKey:key];
        }
        
        // check group
        if (grouped && [annotation respondsToSelector:@selector(groupTag)]) {
            if (![clusterAnnotation.groupTag isEqualToString:((id <OCGrouping>)annotation).groupTag])
                continue;
        }
        
        // add annotation to the cluster
        [clusterAnnotation addAnnotation:annotation];
	}
    
    // return array
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
    // whipe all empty or single annotations
    for (OCClusteredAnnotation *anAnnotation in [clusteredAnnotations allValues]) {
        if ([anAnnotation.annotationsInCluster count] <= 1) {
            [returnArray addObject:[anAnnotation.annotationsInCluster lastObject]];
        }
        else{
            [returnArray addObject:anAnnotation];
        }
    }
    
    return returnArray;
}

+ (NSString*) localizedDistanceStringFromKilometers:(CLLocationDistance)kilometers lessThanKilometerAccuracy:(BOOL)lessThanKilometerAccuracy {
    NSString *distanceString = @"";
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Metric"] boolValue]) {
        if (kilometers >= 1||lessThanKilometerAccuracy) {
            if (lessThanKilometerAccuracy) {
                distanceString = [NSString stringWithFormat:@"%.1f%@", kilometers, @"km"];
            } else {
                distanceString = [NSString stringWithFormat:@"%.0f%@", kilometers, @"km"];
            }
        } else {
            if (kilometers == 0) {
                distanceString = @"";
            } else {
                distanceString = [NSString stringWithFormat:@"0-1km"];
            }
        }
    } else {
        CLLocationDistance miles = kilometers*0.621371192;
        if (miles >= 1||lessThanKilometerAccuracy) {
            if (lessThanKilometerAccuracy) {
                distanceString = [NSString stringWithFormat:@"%.1f%@", miles, @"mi"];
            } else {
                distanceString = [NSString stringWithFormat:@"%.0f%@", miles, @"mi"];
            }
        } else {
            if (miles == 0) {
                distanceString = @"";
            } else {
                distanceString = [NSString stringWithFormat:@"0-1mi"];
            }
        }
        
    }
    return distanceString;
}

@end