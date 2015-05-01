#import <Foundation/Foundation.h>
@import MediaLibrary;
#import <ReactiveCocoa.h>

@interface PhotosClient : NSObject
@property (nonatomic, retain) MLMediaLibrary *mediaLibrary;
@property (nonatomic, retain) MLMediaSource *mediaSource;
@property (nonatomic, retain) MLMediaGroup *allPhotosAlbum;
-(RACSignal*)loadMediaObjects;
-(RACSignal*)loadMediaGroups;
@end
