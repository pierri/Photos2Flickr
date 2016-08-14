#import <Foundation/Foundation.h>
@import MediaLibrary;
#import <ReactiveCocoa.h>

@interface PhotosClient : NSObject
@property (nonatomic, retain) NSArray *mediaObjects;
-(RACSignal*)loadMediaGroups;
@end
