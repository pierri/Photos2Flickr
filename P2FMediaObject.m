#import "P2FMediaObject.h"
#import "Photos2Flickr.h"

@interface P2FMediaObject()

@property (nonatomic) MLMediaObject *mediaObject;

@end

@implementation P2FMediaObject
- (id)initWithMediaObject:(MLMediaObject*) mediaObject {
    self = [super init];
    self.mediaObject = mediaObject;
    return self;
}

-(NSString*)identifier {
    return [_mediaObject identifier];
}

-(NSString*)title {
    NSString *title = [_mediaObject name];
    
    // when image has no caption, use file name instead
    if (title == nil) {
        NSString *photosMediaURL = [[_mediaObject originalURL] absoluteString];
        title = [[photosMediaURL lastPathComponent]stringByDeletingPathExtension];
        title = [title stringByRemovingPercentEncoding]; // e.g. replace "%20" with " "
    }
    
    title = [title stringByReplacingOccurrencesOfString:@"~" withString:@"_"]; // tildes in the caption generate an invalid XML upload reponse (ObjectiveFlickr error 2147418115)
    
    return title;
}

-(NSString*)description {
    NSString *description = [[_mediaObject attributes] objectForKey:@"Comment"];
    if (description == nil) {
        description = @"";
    }
    return description;
}

-(NSURL*)url {
    return [_mediaObject URL];
}

-(NSArray*)facesNames {
    NSArray* facesInPic = [[_mediaObject attributes] objectForKey:@"FaceList"];
    
    NSArray* facesNames = [facesInPic valueForKey:@"name"];
    
    return facesNames;
}

-(NSUInteger)fileSize {
    return [_mediaObject fileSize];
}

-(NSDate*)modificationDate {
    return [_mediaObject modificationDate];
}

-(NSString *)machineTag {
    NSString *photosMediaObjectIdentifier = [self identifier];
    NSString *machineTag = [NSString stringWithFormat:@"%@%@ ", kMachineTagPrefix, photosMediaObjectIdentifier];
    return machineTag;
}


@end
