//
//  OCAlgorythms.h
//  openClusterMapView
//
//  Created by Botond Kis on 15.07.11.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


/// Enumaration for the clustering methods
/** Contains all clustering methods which are aviable in OCMapView yet*/
typedef enum {
    OCClusteringMethodBubble,
    OCClusteringMethodGrid
} OCClusteringMethod;

/// Protocol for notifying on Cluster events. NOT in use yet.
/** Implement this protocol if you are using asynchronous clustering algorithms.
 In fact, there isn't one yet. This just demonstrates where this class will develop to in future.*/
@protocol OCAlgorithmDelegate <NSObject>
@required
/// Called when an algorithm finishes a block of calculations
- (NSArray *)algorithmClusteredPartially;
@optional
/// Called when algorithm starts calculating.
- (void)algorithmDidBeganClustering;
/// Called when algorithm finishes calculating.
- (void)algorithmDidFinishClustering;
@end

/// Class containing clustering algorithms.
/** The first release of OCMapView brings two different algorithms.
 This class is supposed to hold those algorithms.
 More algorithms are planned for future releases of OCMapView.
 
 Note for OCMapView developers:
 Every algorithm has to be a class method which returns an array of OCClusteredAnnotations or a subclass of it. 
 OR for future releases
 They can be instance methods if they run asynchronously. The instance holder needs to implement the delegate protocol and the method needs to call the delegate.
 */
@interface OCAlgorithms : NSObject{
    /// Delegate for notifying on finished tasks
    /** NOT USED YET.
     Just reserved for future usage.*/
    id <OCAlgorithmDelegate> delegate;
}

/// Bubble clustering with iteration
/** This algorithm creates clusters based on the distance
 between single annotations.
 
 @param annotationsToCluster contains the Annotations that should be clustered
 @param clusteredAnnotations contains the Annotations that are already clustered and there information could be used again, for animations
 @param radius represents the cluster size. 
 
 It iterates through all annotations in the array and compare their distances. If they are near engough, they will be clustered.*/
+ (NSArray*) bubbleClusteringWithAnnotations:(NSArray *) annotationsToCluster alreadyClusteredAnnotations:(NSArray*) clusteredAnnotations andClusterRadius:(CLLocationDistance)radius grouped:(BOOL) grouped;



/// Grid clustering with predefined size
/** This algorithm creates clusters based on a defined grid.
 
 @param annotationsToCluster contains the Annotations that should be clustered
 @param clusteredAnnotations contains the Annotations that are already clustered and there information could be used again, for animations
 @param tileRect represents the size of a grid tile. 
 
 It iterates through all annotations in the array and puts them into a grid tile based on their location.*/
+ (NSArray*) gridClusteringWithAnnotations:(NSArray *) annotationsToCluster alreadyClusteredAnnotations:(NSArray*) clusteredAnnotations andClusterRect:(MKCoordinateSpan)tileRect grouped:(BOOL) grouped;


// Localized String, checking if Metric or Not.
/** This conviences method allows those silly people stuck in the past to have miles instead of km, based on there localized info.
 
 @param kilometeres, to make localized string from.
 
 We like.*/
+ (NSString*) localizedDistanceStringFromKilometers:(CLLocationDistance)kilometers lessThanKilometerAccuracy:(BOOL)lessThanKilometerAccuracy;

@end
