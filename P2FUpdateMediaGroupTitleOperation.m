#import "P2FUpdateMediaGroupTitleOperation.h"
#import "Underscore.h"
#define _ Underscore

@implementation P2FUpdateMediaGroupTitleOperation

-(RACSignal*)execute {
    P2FMediaGroup* mediaGroup = super.mediaGroup;
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSString *mediaGroupIdentifier = [mediaGroup identifier];
    NSString *flickrPhotosetId = [flickrClient getFlickrPhotosetIdForIdentifier:mediaGroupIdentifier];
    
    NSString *title = [mediaGroup name];
    
    RACSignal *updateSignal = [flickrClient editPhotoset:flickrPhotosetId title:title];
    
    [updateSignal subscribeError:^(NSError *error) {
        
        NSLog(@"Error during update: %@", [error localizedDescription]);
        
        // TODO not implemented yet
        [progressSignal sendNext:@([self getSizeBytes])]; // TODO remove - for testing purposes only
        [progressSignal sendCompleted];
        
    } completed:^{
        [progressSignal sendNext:@([self getSizeBytes])];
        [progressSignal sendCompleted];
    }];
    
    return progressSignal;
}


-(UnderscoreTestBlock)removeNil {
    return ^BOOL (id value) {
        return value != nil;
    };
}

- (UnderscoreArrayMapBlock)getFlickrPhotoIdForMediaObjectId {
    return ^NSString* (NSString* mediaObjectId) {
        FlickrClient *flickrClient = [FlickrClient sharedClient];
        
        return [flickrClient getFlickrPhotoIdForRawIdentifier:mediaObjectId];;
    };
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Update album %@", [super.mediaGroup name]];
}

@end
