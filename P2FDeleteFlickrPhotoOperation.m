#import "P2FDeleteFlickrPhotoOperation.h"

@implementation P2FDeleteFlickrPhotoOperation

- (id)initWithFlickrPhotoId:(NSString *) flickrPhotoId {
    self = [super init];
    self.flickrPhotoId = flickrPhotoId;
    return self;
}

-(RACSignal*)execute {
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    RACSubject *progressSignal = [[RACSubject alloc]init];
    [progressSignal sendNext:@(0)];
    
    RACSignal *deleteSignal = [flickrClient deletePhoto:_flickrPhotoId];
    
    [deleteSignal subscribeCompleted:^{
        [progressSignal sendCompleted];
    }];
    
    return progressSignal;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Delete flickr photo %@", _flickrPhotoId];
}

@end
