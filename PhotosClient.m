#import "PhotosClient.h"
#import "Underscore.h"
#define _ Underscore

static NSString *const kMediaSourcesContext = @"mediaSources";
static NSString *const kRootMediaGroupContext = @"mediaGroup";
static NSString *const kMediaObjects = @"mediaObjects";
static NSString *const kAlbumMediaObjects = @"albumMediaObjects";

@implementation PhotosClient

-(RACSignal*)loadMediaGroups {
    
    _mediaObjects = [[NSArray alloc]init];
    NSMutableSet *mediaObjectsSet = [[NSMutableSet alloc]init];
    
    _mediaGroups = [[NSMutableArray alloc]init];
    RACSubject *mediaGroupsSignal = [[RACSubject alloc]init];
    
    BOOL (^removeNil)(id) = ^BOOL(id value){
        return value != nil;
    };
    
    RACDisposable *(^once) (id<RACSubscriber>) = ^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:nil];
        [subscriber sendCompleted];
        return nil;
    };
    
    // Trigger asynchronous load of media library
    NSDictionary *options = @{
                              MLMediaLoadSourceTypesKey: @(MLMediaSourceTypeImage),
                              MLMediaLoadIncludeSourcesKey: @[MLMediaSourcePhotosIdentifier]};
    
    MLMediaLibrary *mediaLibrary = [[MLMediaLibrary alloc] initWithOptions:options];
    
    RACSignal *mediaLibraryUpdated = [RACObserve(mediaLibrary, mediaSources) filter:removeNil];
    [mediaLibraryUpdated subscribeNext:^(NSDictionary *mediaSources) {
        NSLog(@"Photos library loaded");
        
        MLMediaSource *mediaSource = [mediaLibrary.mediaSources objectForKey:@"com.apple.Photos"];
        
        RACSignal *mediaSourcesUpdated = [RACObserve(mediaSource, rootMediaGroup) filter:removeNil];
        [mediaSourcesUpdated subscribeNext:^(MLMediaGroup *rootMediaGroup) {
            NSLog(@"Albums list loaded");
            
            MLMediaGroup *sharedAlbums = [mediaSource mediaGroupForIdentifier:@"com.apple.Photos.SharedGroup"];
            MLMediaGroup *topLevelAlbums = [mediaSource mediaGroupForIdentifier:@"TopLevelAlbums"];
            NSArray *albums = [sharedAlbums.childGroups arrayByAddingObjectsFromArray:topLevelAlbums.childGroups];
            
            RACSignal *allMediaGroupsLoaded = [RACSignal createSignal:once];
            
            for (MLMediaGroup* album in albums) {
                
                NSString *albumIdentifier = [album.attributes objectForKey:@"identifier"];
                NSString *albumTypeIdentifier = [album.attributes objectForKey:@"typeIdentifier"];
                
                if ([albumTypeIdentifier isEqualTo:@"com.apple.Photos.Album"] || [albumIdentifier isEqualTo:@"allPhotosAlbum"] || [albumTypeIdentifier isEqualTo:@"com.apple.Photos.SharedPhotoStream"]) {
                    
                    RACSignal *mediaObjectsLoaded = [RACObserve(album, mediaObjects) filter:removeNil];
                    RACSubject *thisAlbumLoaded = [[RACSubject alloc]init];
                    allMediaGroupsLoaded = [allMediaGroupsLoaded zipWith:thisAlbumLoaded];
                    
                    [mediaObjectsLoaded subscribeNext:^(id mediaObjects) {
                        
                        [mediaObjectsSet addObjectsFromArray:mediaObjects];
                        
                        [_mediaGroups addObject:album];
                        
                        [mediaGroupsSignal sendNext:album];
                        [thisAlbumLoaded sendNext:nil];
                    }];
                }
            };
            
            [allMediaGroupsLoaded subscribeCompleted:^{
                _mediaObjects = [mediaObjectsSet allObjects];
                NSLog(@"Media groups loaded, total %lu media objects", (unsigned long)[_mediaObjects count]);
                [mediaGroupsSignal sendCompleted];
            }];
        }];
    }];
    
    return mediaGroupsSignal;
}

@end
