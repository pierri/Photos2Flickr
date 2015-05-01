#import <Foundation/Foundation.h>
@import MediaLibrary;
#import "PhotosClient.h"
#import "Photos2Flickr.h"

@interface P2FMenulet : NSObject <NSApplicationDelegate, Photos2FlickrDelegate> {
    NSStatusItem *statusItem;
}

- (IBAction)onPressUploadNow:(id)sender;
- (IBAction)onPressStopUploading:(id)sender;
- (IBAction)onPressOpenPreferences:(id)sender;

@end