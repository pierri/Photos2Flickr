#import <Foundation/Foundation.h>
@import MediaLibrary;
#import <ReactiveCocoa.h>

@interface PhotosClient : NSObject
@property (nonatomic, retain) MLMediaLibrary *mediaLibrary;
@property (nonatomic, retain) MLMediaSource *mediaSource;
@property (nonatomic, retain) MLMediaGroup *allPhotosAlbum;
@property (nonatomic, retain) NSArray *mediaObjects;
-(RACSignal*)loadMediaObjects;
-(RACSignal*)loadMediaGroups;
@end
