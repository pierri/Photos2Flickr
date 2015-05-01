#import <Foundation/Foundation.h>
#import "FlickrClient.h"
#import "PhotosClient.h"
#import "P2FOperation.h"

@import MediaLibrary;

static NSString * const kMachineTagPrefix = @"Photos2Flickr:identifier=";

@protocol Photos2FlickrDelegate <NSObject>
@optional
-(void)processStarting;
-(void)progressBytesUploaded:(NSUInteger)bytesUploaded totalBytesToUpload:(NSUInteger)bytesToUpload;
-(void)processInterrupted;
@end

@interface Photos2Flickr : NSObject
@property (nonatomic, retain) id <Photos2FlickrDelegate> delegate;
-(void) uploadMedia;
@property (nonatomic) FlickrClient *flickrClient;

@end
