#import "PhotosClient.h"
#import "Underscore.h"
#define _ Underscore

static NSString *const kMediaSourcesContext = @"mediaSources";
static NSString *const kRootMediaGroupContext = @"mediaGroup";
static NSString *const kMediaObjects = @"mediaObjects";
static NSString *const kAlbumMediaObjects = @"albumMediaObjects";

@implementation PhotosClient

-(RACSignal*)loadMediaObjects {
    
    RACSubject *mediaObjectsSignal = [[RACSubject alloc]init];
    
    BOOL (^removeNil)(id) = ^BOOL(id value){
        return value != nil;
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
            
            MLMediaGroup *albums = [mediaSource mediaGroupForIdentifier:@"TopLevelAlbums"];
            
            MLMediaGroup *allPhotosAlbum;
            for (MLMediaGroup *album in albums.childGroups) {
                NSString *albumIdentifier = [album.attributes objectForKey:@"identifier"];
                
                if (![albumIdentifier isEqualTo:@"allPhotosAlbum"]) {
                    continue;
                }
                
                allPhotosAlbum = album;
                break;
            }
            
            RACSignal *allPhotosAlbumUpdated = [RACObserve(allPhotosAlbum, mediaObjects) filter:removeNil];

            [allPhotosAlbumUpdated subscribeNext:^(NSArray* mediaObjects) {
                NSLog(@"Media objects loaded");
                _mediaObjects = mediaObjects;
                [mediaObjectsSignal sendCompleted];
            }];
            
        }];
        
    }];
    
    return mediaObjectsSignal;
}

-(RACSignal*)loadMediaGroups {
    
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
            
            MLMediaGroup *topLevel = [mediaSource mediaGroupForIdentifier:@"TopLevelAlbums"];
            
            RACSignal *topLevelMediaGroups = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
                _.array(topLevel.childGroups).each(^(MLMediaGroup *topLevelAlbum) {
                    [subscriber sendNext:topLevelAlbum];
                });
                [subscriber sendCompleted];
                return nil;
            }];
            
            RACSignal *topLevelAlbums = [topLevelMediaGroups filter:^BOOL(MLMediaGroup* album) {
                NSString *albumTypeIdentifier = [album.attributes objectForKey:@"typeIdentifier"];
                if ([albumTypeIdentifier isEqualTo:@"com.apple.Photos.Album"]) {
                    return YES;
                }
                return NO;
            }];
                        
            RACSignal *allMediaGroupsLoaded = [RACSignal createSignal:once];
            
            for (MLMediaGroup* album in topLevel.childGroups) {
                
                NSString *albumTypeIdentifier = [album.attributes objectForKey:@"typeIdentifier"];
                
                if ([albumTypeIdentifier isEqualTo:@"com.apple.Photos.Album"]) {
                    
                    RACSignal *mediaObjectsLoaded = [RACObserve(album, mediaObjects) filter:removeNil];
                    RACSubject *thisAlbumLoaded = [[RACSubject alloc]init];
                    allMediaGroupsLoaded = [allMediaGroupsLoaded zipWith:thisAlbumLoaded];
                    
                    [mediaObjectsLoaded subscribeNext:^(id mediaObjects) {
                        [mediaGroupsSignal sendNext:album];
                        [thisAlbumLoaded sendNext:nil];
                    }];
                }
            };
            
            [allMediaGroupsLoaded subscribeCompleted:^{
                NSLog(@"Media groups loaded");
                [mediaGroupsSignal sendCompleted];
            }];
        }];
    }];
    
    return mediaGroupsSignal;
}

@end
