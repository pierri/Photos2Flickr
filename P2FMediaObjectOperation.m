#import "P2FMediaObjectOperation.h"

@implementation P2FMediaObjectOperation

- (id)initWithMediaObject:(P2FMediaObject*) mediaObject {
    self = [super init];
    self.mediaObject = mediaObject;
    return self;
}

@end
