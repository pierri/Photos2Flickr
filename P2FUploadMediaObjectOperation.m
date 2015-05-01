#import "P2FUploadMediaObjectOperation.h"

@interface P2FUploadMediaObjectOperation()

@end


@implementation P2FUploadMediaObjectOperation
    
-(RACSignal*)execute {
    P2FMediaObject* mediaObject = super.mediaObject;
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSURL *photosMediaObjectURL = [mediaObject url];
    
    NSString *title = [mediaObject title];
    
    NSString *description = [mediaObject description];
    
    NSArray *facesNames = [mediaObject facesNames];
    
    NSString *machineTag = [mediaObject machineTag];
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    RACSignal *uploadSignal = [flickrClient uploadImage:photosMediaObjectURL
                                                  title:title
                                            description:description
                                             facesNames:facesNames
                                             machineTag:machineTag];
    
    [uploadSignal subscribeNext:^(NSNumber* bytesSent) {
        
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
    return [NSString stringWithFormat:@"Upload %@", [super.mediaObject title]];
}

@end
