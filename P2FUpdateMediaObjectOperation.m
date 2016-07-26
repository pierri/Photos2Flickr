#import "P2FUpdateMediaObjectOperation.h"


@implementation P2FUpdateMediaObjectOperation

-(RACSignal*)execute {
    P2FMediaObject* mediaObject = super.mediaObject;
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    NSURL *photosMediaObjectURL = [mediaObject url];
    
    NSString *mediaObjectId = [mediaObject identifier];
    NSString *flickrPhotoId = [flickrClient getFlickrPhotoIdForRawIdentifier:mediaObjectId];
    
    RACSignal *updateSignal = [flickrClient replaceImage:photosMediaObjectURL
                                                 photoId:flickrPhotoId];
    
    [updateSignal subscribeCompleted:^{
        NSString *flickrPhotoId = [flickrClient getUploadedPhotoId];
        
        if (flickrPhotoId != nil) {
            NSString *photosMediaObjectIdentifier = [mediaObject identifier];
            [flickrClient setFlickrPhotoId:flickrPhotoId forRawIdentifier:photosMediaObjectIdentifier];
        }
    }];
    
    return updateSignal;
}

-(NSUInteger)getSizeBytes {
    return [self.mediaObject fileSize];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Update %@", [super.mediaObject title]];
}

@end
