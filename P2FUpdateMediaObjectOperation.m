#import "P2FUpdateMediaObjectOperation.h"


@implementation P2FUpdateMediaObjectOperation

-(RACSignal*)execute {
    P2FMediaObject* mediaObject = super.mediaObject;
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSURL *photosMediaObjectURL = [mediaObject url];
    
    NSString *mediaObjectId = [mediaObject identifier];
    NSString *flickrPhotoId = [flickrClient getFlickrPhotoIdForRawIdentifier:mediaObjectId];
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    RACSignal *updateSignal = [flickrClient replaceImage:photosMediaObjectURL
                                                 photoId:flickrPhotoId];
    
    [updateSignal subscribeNext:^(NSNumber* bytesSent) {
        
        [progressSignal sendNext:bytesSent];
        
    } error:^(NSError *error) {
        
        NSLog(@"Error during upload: %@", [error localizedDescription]);
        
        // TODO not implemented yet
        [progressSignal sendNext:@([self getSizeBytes])]; // TODO remove - for testing purposes only
        [progressSignal sendCompleted];
        
    } completed:^{
        NSString *flickrPhotoId = [flickrClient getUploadedPhotoId];
        
        if (flickrPhotoId != nil) {
            NSString *photosMediaObjectIdentifier = [mediaObject identifier];
            [flickrClient setFlickrPhotoId:flickrPhotoId forRawIdentifier:photosMediaObjectIdentifier];
        }
        
        [progressSignal sendCompleted];
    }];
    
    return progressSignal;
}

-(NSUInteger)getSizeBytes {
    return [self.mediaObject fileSize];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Update %@", [super.mediaObject title]];
}

@end
