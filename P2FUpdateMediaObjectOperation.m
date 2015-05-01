#import "P2FUpdateMediaObjectOperation.h"


@implementation P2FUpdateMediaObjectOperation

-(RACSignal*)execute {
    P2FMediaObject* mediaObject = super.mediaObject;
    
    NSString *title = [mediaObject title];
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    NSString *progress = [NSString stringWithFormat:@"Updating %@", title];
    [progressSignal sendNext:progress];

    return progressSignal;
}

@end
