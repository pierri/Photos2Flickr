#import <Foundation/Foundation.h>
@import MediaLibrary;
#import <ReactiveCocoa.h>

@interface PhotosClient : NSObject
@property (nonatomic, retain) NSArray *mediaObjects;
@property (nonatomic, retain) NSMutableArray *mediaGroups;
-(RACSignal*)loadMediaGroups;
@end
