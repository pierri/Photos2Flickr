#import "P2FUpdateMediaGroupPicsOperation.h"
#import "Underscore.h"
#define _ Underscore

@implementation P2FUpdateMediaGroupPicsOperation

-(RACSignal*)execute {
    P2FMediaGroup* mediaGroup = super.mediaGroup;
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSString *mediaGroupIdentifier = [mediaGroup identifier];
    NSString *flickrPhotosetId = [flickrClient getFlickrPhotosetIdForIdentifier:mediaGroupIdentifier];
        
    NSString *keyPhotoIdentifier = [mediaGroup keyPhotoIdentifier];
    NSString *flickrPrimaryPhotoId = [flickrClient getFlickrPhotoIdForRawIdentifier:keyPhotoIdentifier];
  
    NSArray *mediaObjectIds = [mediaGroup mediaObjectsIdentifiers];
    NSArray *flickrPhotoIdsArray = _.array(mediaObjectIds)
                                    .map(self.getFlickrPhotoIdForMediaObjectId)
                                    .filter(self.removeNil)
                                    .unwrap;
    NSString *flickrPhotoIdsString = [flickrPhotoIdsArray componentsJoinedByString:@","];
    
    // TODO proper error handling
    if ([flickrPrimaryPhotoId length] == 0 || [flickrPhotoIdsArray count] == 0) {
        [progressSignal sendNext:@([self getSizeBytes])]; // TODO remove - for testing purposes only
        [progressSignal sendCompleted];
    }
    
    RACSignal *updateSignal = [flickrClient editPhotoset:flickrPhotosetId
                                          primaryPhotoId:flickrPrimaryPhotoId
                                                photoIds:flickrPhotoIdsString];
    
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
