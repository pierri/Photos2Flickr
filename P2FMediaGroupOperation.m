#import "P2FMediaGroupOperation.h"

@implementation P2FMediaGroupOperation

- (id)initWithMediaGroup:(P2FMediaGroup*) mediaGroup {
    self = [super init];
    self.mediaGroup = mediaGroup;
    return self;
}


@end
