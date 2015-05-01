#import "P2FOperation.h"

@implementation P2FOperation

- (id)init {
    self = [super init];
    return self;
}

-(NSUInteger)getSizeBytes { 
    return 50000; // default size assumed for a JSON request
}

@end
