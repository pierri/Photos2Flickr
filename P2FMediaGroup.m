#import "P2FMediaGroup.h"

@interface P2FMediaGroup()

@property (nonatomic) MLMediaGroup *mediaGroup;

@end

@implementation P2FMediaGroup
- (id)initWithMediaGroup:(MLMediaGroup*) mediaGroup {
    self = [super init];
    self.mediaGroup = mediaGroup;
    return self;
}

-(NSString*)name {
    return [self.mediaGroup name];
}

-(NSString*)identifier {
    return [self.mediaGroup identifier];
}

-(NSDate*)modificationDate {
    return [self.mediaGroup modificationDate];
}

-(NSArray*)mediaObjectsIdentifiers {
    return [[self.mediaGroup attributes] objectForKey:@"KeyList"];
    // this is available only after requesting [mediaGroup mediaObjects] as done in PhotosClient upfront
}

-(NSString*)keyPhotoIdentifier {
    return [[self.mediaGroup attributes] objectForKey:@"KeyPhotoKey"];
}

@end
