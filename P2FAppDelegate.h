#import <Cocoa/Cocoa.h>
#import "FlickrClient.h"
#import "Photos2Flickr.h"
#import "P2FMenulet.h"

/// Responsible for the lifecycle of the FlickrClient and Photos2Flickr instances:
/// - Creates a FlickrClient and requests the user's permission
/// - Creates the Photos2Flickr object and sets the FlickrClient
/// - Provides methods to start/stop the processing

@interface P2FAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, retain) IBOutlet P2FMenulet *menulet;

-(void)startProcessing;
-(void)stopProcessing;

@end
