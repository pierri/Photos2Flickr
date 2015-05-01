#import "P2FCreateMediaGroupOperation.h"
#import "Photos2Flickr.h"

@implementation P2FCreateMediaGroupOperation

-(RACSignal*)execute {
    P2FMediaGroup* mediaGroup = super.mediaGroup;
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSString *name = [mediaGroup name];
    
    NSString *mediaGroupIdentifier = [mediaGroup identifier];
    
    NSString *description = [kMachineTagPrefix stringByAppendingString:mediaGroupIdentifier];
    
    NSString *keyPhotoIdentifier = [mediaGroup keyPhotoIdentifier];
    NSString *flickrPrimaryPhotoId = [flickrClient getFlickrPhotoIdForRawIdentifier:keyPhotoIdentifier];

    // TODO error handling when primary photo ID is not set!
    if ([flickrPrimaryPhotoId length] == 0) {
        [progressSignal sendNext:@([self getSizeBytes])]; // TODO remove - for testing purposes only
        [progressSignal sendCompleted];
    }
    
    RACSignal *createSignal = [flickrClient createPhotosetTitle:name
                                                    description:description
                                                 primaryPhotoId:flickrPrimaryPhotoId];
    
    [createSignal subscribeError:^(NSError *error) {
        
        NSLog(@"Error during creation: %@", [error localizedDescription]);
        
        // TODO not implemented yet
        [progressSignal sendNext:@([self getSizeBytes])]; // TODO remove - for testing purposes only
        [progressSignal sendCompleted];
        
    } completed:^{
        
        NSString *photosetId = [flickrClient getCreatedPhotosetId];
        [flickrClient setFlickrPhotosetId:photosetId forMediaGroupIdentifier:mediaGroupIdentifier];
        
        [progressSignal sendNext:@([self getSizeBytes])];
        [progressSignal sendCompleted];
    }];
    
    return progressSignal;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Create album %@", [super.mediaGroup name]];
}

@end
