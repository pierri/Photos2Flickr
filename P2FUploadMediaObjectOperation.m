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
    
    
    RACSignal *uploadSignal = [flickrClient uploadImage:photosMediaObjectURL
                                                  title:title
                                            description:description
                                             facesNames:facesNames
                                             machineTag:machineTag];
    
    [uploadSignal subscribeError:^(NSError *error) {
        
        NSLog(@"Error: %@", [error localizedDescription]);
        NSLog(@"URL: %@", photosMediaObjectURL);
        
    } completed:^{
        NSString *flickrPhotoId = [flickrClient getUploadedPhotoId];
        
        if (flickrPhotoId != nil) {
            NSString *photosMediaObjectIdentifier = [mediaObject identifier];
            [flickrClient setFlickrPhotoId:flickrPhotoId forRawIdentifier:photosMediaObjectIdentifier];
        }
        
    }];
    
    return uploadSignal;
}

-(NSUInteger)getSizeBytes {
    return [self.mediaObject fileSize];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Upload %@", [super.mediaObject title]];
}

@end
