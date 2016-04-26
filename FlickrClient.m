#import "FlickrClient.h"
#import <AppKit/AppKit.h>
#import <objectiveflickr/ObjectiveFlickr.h>

// Internal
static NSString * const kSignalOperation = @"The current operation returns a RACSignal";

static NSString * const kStoredAuthTokenKeyName = @"FlickrOAuthToken";
static NSString * const kStoredAuthTokenSecretKeyName = @"FlickrOAuthTokenSecret";

static NSString * const kFlickrClientAPIURL   = @"https://api.flickr.com/services/";

static NSString * const kFlickrClientOAuthAuthorizeURL     = @"https://www.flickr.com/services/oauth/authorize";

static NSString * const kFlickrClientOAuthRequestTokenPath = @"oauth/request_token";
static NSString * const kFlickrClientOAuthAccessTokenPath  = @"oauth/access_token";

#pragma mark -
@interface FlickrClient() <OFFlickrAPIRequestDelegate>
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *requestToken;
- (id)initWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
- (NSDictionary *)defaultRequestParameters;
@property (nonatomic) OFFlickrAPIContext *flickrContext;
@property (nonatomic) OFFlickrAPIRequest *flickrRequest;
@property (nonatomic) int pages;
@property (nonatomic) NSDictionary *responseDict;
@property (nonatomic) RACSubject *currentOperationSignal;
@property (nonatomic) NSDate* previousStart;
@end


@implementation FlickrClient


#pragma mark Initialization ------------------------------------------------------------------------------

static FlickrClient *_sharedClient = nil;

+ (instancetype)createWithAPIKey:(NSString *)apiKey secret:(NSString *)secret {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[[self class] alloc] initWithAPIKey:apiKey secret:secret];
    });
    
    return _sharedClient;
}

- (id)initWithAPIKey:(NSString *)apiKey secret:(NSString *)secret {
    self = [super init];
    
    if (self) {
        _apiKey = [apiKey copy];
        
        self.flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:apiKey sharedSecret:secret];
        
        // TODO OAuthToken and OAuthTokenSecret should be stored in the keychain instead of here...
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                     nil, kStoredAuthTokenKeyName,
                                     nil, kStoredAuthTokenSecretKeyName,
                                     nil];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults registerDefaults:appDefaults];
        
        self.flickrContext.OAuthToken = [defaults valueForKey:kStoredAuthTokenKeyName];
        self.flickrContext.OAuthTokenSecret = [defaults valueForKey:kStoredAuthTokenSecretKeyName];
    
        self.flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrContext];
        self.flickrRequest.delegate = self;
        self.flickrRequest.requestTimeoutInterval = 60.0;
        
        self.ready = [[RACSubject alloc]init];
        
    }
    
    return self;
}

+ (instancetype)sharedClient {
    NSAssert(_sharedClient, @"FlickrClient not initialized. [FlickrClient createWithAPIKey:secret:] must be called first.");
    
    return _sharedClient;
}

- (BOOL)isAuthorized {
    if (self.flickrContext.OAuthToken && [self.flickrContext.OAuthToken isNotEqualTo: @""]) {
        return true;
    }
    return false;
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError {
    
    if ([self currentOperationReturnsSignal]) {
        [_currentOperationSignal sendError:inError];
        [_currentOperationSignal sendCompleted];
        [self sendReadyASAP];
    } else {
        NSLog(@"Error %@", [inError localizedDescription]);
    }
}

-(BOOL)currentOperationReturnsSignal {
    if ([kSignalOperation isEqualToString:_flickrRequest.sessionInfo]) {
        return true;
    }
    return false;
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret {
    
    NSLog(@"Received request token %@", inRequestToken);
    
    self.flickrContext.OAuthToken = inRequestToken;
    self.flickrContext.OAuthTokenSecret = inSecret;
    
    NSURL *authURL = [self.flickrContext userAuthorizationURLWithRequestToken:inRequestToken requestedPermission:OFFlickrDeletePermission];
    
    if (![[NSWorkspace sharedWorkspace] openURL:authURL])
        NSLog(@"Failed to open url: %@", [authURL description]);
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID {
    
    _flickrContext.OAuthToken = inAccessToken;
    _flickrContext.OAuthTokenSecret = inSecret;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_flickrContext.OAuthToken forKey:kStoredAuthTokenKeyName];
    [defaults setValue:_flickrContext.OAuthTokenSecret forKey:kStoredAuthTokenSecretKeyName];
    
    NSLog(@"Flickr Client Did Log In %@ (%@)", inFullName, inNSID);
}

- (void)requestAuthorization {
    [self.flickrRequest fetchOAuthRequestTokenWithCallbackURL:[NSURL URLWithString:kFlickrClientOAuthCallbackURL]];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
}

- (BOOL)verifyAuthorizationWithToken:(NSString *)verifierToken {
    
    NSLog(@"Verifying auth with request token %@, verifier token %@", self.flickrContext.OAuthToken, verifierToken);
    
    [self.flickrRequest fetchOAuthAccessTokenWithRequestToken:self.flickrContext.OAuthToken verifier:verifierToken];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    
    return true;
}

- (void)deauthorize {
    _flickrContext.OAuthToken = nil;
    _flickrContext.OAuthTokenSecret = nil;
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:kStoredAuthTokenKeyName];
    [defaults setValue:nil forKey:kStoredAuthTokenSecretKeyName];

}

- (NSDictionary *)defaultRequestParameters {
    return @{@"api_key":        self.apiKey,
             @"format":         @"json",
             @"nojsoncallback": @(1)};
}


#pragma mark Upload ------------------------------------------------------------------------------------

- (RACSignal*)uploadImage:(NSURL *)inImageURL title:(NSString*)title description:(NSString*)description facesNames:(NSArray*)facesNames machineTag:(NSString*)machineTag {

    NSString *facesSpaceSeparatedTag = [self buildSpaceSeparatedStringForTags:facesNames];
    
    NSString *tags = [machineTag stringByAppendingString:facesSpaceSeparatedTag];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            title, @"title",
                            description, @"description",
                            tags, @"tags",
                            @"2", @"hidden",
                            @"0", @"is_public",
                            @"0", @"is_friend",
                            @"0", @"is_family",
                            nil];

    return [self uploadImage:inImageURL params:params];
}

/** Sends next on ready signal, automatically waiting at least 1 second between calls. */
-(void) startProcessing {
    NSLog(@"Flickr client starts accepting requests");
    [self sendReadyASAP];
}

/** private */
-(void)sendReadyASAP {
    if (_previousStart == nil) {
        [self sendReady];
    } else {
        NSDate *currentStart = [[NSDate alloc]init];
        
        NSTimeInterval timeSinceLastCall = [currentStart timeIntervalSinceDate:_previousStart];
        
        NSTimeInterval minimalTimeBetweenSubsequentCalls = 1.0; /* seconds */
        
        if (timeSinceLastCall > minimalTimeBetweenSubsequentCalls) {
            [self sendReady];
        } else {
            double timeToWaitTillNextCall = minimalTimeBetweenSubsequentCalls - timeSinceLastCall;
            
            [NSTimer scheduledTimerWithTimeInterval:timeToWaitTillNextCall
                                             target:self
                                           selector:@selector(sendReady)
                                           userInfo:nil
                                            repeats:NO];
        }
    }
}

-(void)stopProcessing {
    [((RACSubject*)self.ready) sendCompleted];
}

/** private */
-(void) sendReady {
    _previousStart = [[NSDate alloc]init];
    [((RACSubject*)self.ready) sendNext:@""];
}

- (NSString *)buildSpaceSeparatedStringForTags:(NSArray *)tags {
    NSString *tagsSpaceSeparated = @"";
    
    for (NSString *tag in tags) {
        NSString *tagEscaped = [NSString stringWithFormat:@"\"%@\" ", tag];
        tagsSpaceSeparated = [tagsSpaceSeparated stringByAppendingString:tagEscaped];
    }
    
    return tagsSpaceSeparated;
}

/** private */
- (RACSignal*)uploadImage:(NSURL *)inImageURL params:(NSDictionary*)params {
    
    NSString *mimeType = @"image/jpeg";
    
    _flickrRequest.sessionInfo = kSignalOperation;
    BOOL startUploadSuccessful = [_flickrRequest uploadImageStream:[NSInputStream inputStreamWithURL:inImageURL]
                                                 suggestedFilename:nil
                                                          MIMEType:mimeType
                                                         arguments:params];
    NSAssert(startUploadSuccessful, @"Couldn't start upload - this isn't expected!");
    
    return [self createOperationSignal];
}

-(RACSubject*)createOperationSignal {
    _currentOperationSignal = [[RACSubject alloc]init];
    return _currentOperationSignal;
}

/** deprecated */
- (NSString *)getMimeTypeForImage:(NSString *)inImagePath {
    NSString *mimeType;
    NSString *filename = [inImagePath lastPathComponent];
    NSString *extension = [[filename pathExtension] uppercaseString];
    if ([extension isEqualToString:@"AVI"]) {
        mimeType = @"video/avi";
    } else if ([extension isEqualToString:@"PNG"]) {
        mimeType = @"image/png";
    } else {
        mimeType = @"image/jpeg";
    }
    return mimeType;
}


- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes {
    [_currentOperationSignal sendNext:@(inSentBytes)];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary {
    
    _responseDict = inResponseDictionary;
    
    BOOL shouldCompleteSignal = [self currentOperationReturnsSignal];
    
    _flickrRequest.sessionInfo = nil;
    
    if (shouldCompleteSignal) {
        [_currentOperationSignal sendCompleted];
        [self sendReadyASAP];
    }
}

/** private */
- (BOOL)isRunning {
    return [_flickrRequest isRunning];
}

-(NSString*)getUploadedPhotoId {
    NSDictionary *photoIdDict = [_responseDict objectForKey:@"photoid"];
    NSString *photoId = [photoIdDict objectForKey:@"_text"];
    return photoId;
}

#pragma mark Photos ------------------------------------------------------------------------------------


- (RACSignal*)readAllImagesWithMachineTag:(NSString *)machineTagPrefix {
    
    NSString *machineTagPrefixClean = [FlickrClient cleanTag:machineTagPrefix];
    RACSubject *combinedOperationSignal = [[RACSubject alloc]init];
    _mapCleanIdentifierToFlickrPhoto = [[NSMutableDictionary alloc]init];
    [self recursiveReadImagesWithMachineTag:machineTagPrefixClean pageNo:1 subject:combinedOperationSignal];
    return combinedOperationSignal;
}

-(void) recursiveReadImagesWithMachineTag:(NSString*)machineTagPrefixClean pageNo:(int)pageNo subject:(RACSubject*) subject{
    
    RACSignal *searchOperationSignal = [self searchImagesPage:pageNo];
    
    [searchOperationSignal subscribeCompleted:^{
        NSDictionary *photosDict = [_responseDict objectForKey:@"photos"];
        
        _pages = [[photosDict objectForKey:@"pages"] intValue];
        
        NSArray *photoArray = [photosDict objectForKey:@"photo"];
        
        if (photoArray == nil) {
            return;
        }
        
        for (int i = 0; i < [photoArray count]; i++) {
            NSDictionary *currentPhoto = [photoArray objectAtIndex:i];
            NSString *photoId = [currentPhoto objectForKey:@"id"];
            
            NSString *tagsString = [currentPhoto objectForKey:@"tags"];
            NSArray *tags = [tagsString componentsSeparatedByString:@" "];
            
            NSString *photosMediaIdentifierClean = nil;
            for (int j = 0; j < [tags count]; j++) {
                NSString *tag = [tags objectAtIndex:j];
                if ([tag hasPrefix:machineTagPrefixClean]) {
                    photosMediaIdentifierClean = [tag substringFromIndex:[machineTagPrefixClean length]];
                    break;
                }
            }
            
            if (photosMediaIdentifierClean) {
                
                // following transformations already performed by Flickr somehow, just documenting it here...
                photosMediaIdentifierClean = [FlickrClient cleanTag:photosMediaIdentifierClean];
                
                if ([_mapCleanIdentifierToFlickrPhoto objectForKey:photosMediaIdentifierClean] != nil) {
                    //[duplicates addObject:photoId];
                } else {
                    [_mapCleanIdentifierToFlickrPhoto setObject:currentPhoto forKey:photosMediaIdentifierClean];
                }
            }
        }
        
        NSLog(@"Page %d: %lu entries", pageNo, (unsigned long)[photoArray count]);
        
        if (pageNo <= _pages) {
            [self recursiveReadImagesWithMachineTag:machineTagPrefixClean
                                             pageNo:pageNo + 1
                                            subject:subject];
        } else {
            NSLog(@"Found %lu images already uploaded", (unsigned long)[_mapCleanIdentifierToFlickrPhoto count]);
            [subject sendCompleted];
        }
        
    }];
}


/* private */
+ (NSString*)cleanTag:(NSString*)rawTag {
    NSString *guid = [rawTag copy];
    guid = [guid lowercaseString];
    guid = [guid stringByReplacingOccurrencesOfString:@"%" withString:@""];
    guid = [guid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    guid = [guid stringByReplacingOccurrencesOfString:@"+" withString:@""];
    return guid;
}

- (void)setFlickrPhotoId:(NSString*)flickrPhotoId forRawIdentifier:(NSString*)rawIdentifier {
    NSString *cleanIdentifier = [FlickrClient cleanTag:rawIdentifier];
    NSDictionary *flickrPhoto = [NSDictionary dictionaryWithObjectsAndKeys:flickrPhotoId, @"id", nil];
    [self.mapCleanIdentifierToFlickrPhoto setObject:flickrPhoto forKey:cleanIdentifier];
}

- (NSString*)getFlickrPhotoIdForRawIdentifier:(NSString*)rawIdentifier {
    NSDictionary *flickrPhoto = [self getFlickrPhotoForRawIdentifier:rawIdentifier];
    NSString *flickrPhotoId = [flickrPhoto objectForKey:@"id"];
    return flickrPhotoId;
}

- (NSDictionary*) getFlickrPhotoForRawIdentifier:(NSString*)rawIdentifier {
    NSString *guidForSearch = [FlickrClient cleanTag:rawIdentifier];
    NSDictionary *flickrPhoto = [self.mapCleanIdentifierToFlickrPhoto objectForKey:guidForSearch];
    return flickrPhoto;
}

- (BOOL)flickrPhotoForRawIdentifier:(NSString*)rawIdentifier hasLastChangedBeforeModificationDate:(NSDate*)modificationDate {
    NSDictionary *flickrPhoto = [self getFlickrPhotoForRawIdentifier:rawIdentifier];
    
    NSString *flickrLastUpdateAsString = [flickrPhoto objectForKey:@"lastupdate"];
    NSTimeInterval flickrLastUpdateAsDouble = [flickrLastUpdateAsString doubleValue];
    NSDate *flickrLastUpdate = [NSDate dateWithTimeIntervalSince1970:flickrLastUpdateAsDouble];
    
    if ([flickrLastUpdate compare:modificationDate] == NSOrderedAscending) {
        // flickrLastUpdate is earlier than modificationDate
        return true;
    }
    
    return false;
}
-(void)deleteDuplicates:(NSArray*)duplicates {
    NSLog(@"Deleting %lu duplicates", (unsigned long)[duplicates count]);
    
    for (int i = 0; i < [duplicates count]; i++) {
        NSString *photoId = [duplicates objectAtIndex:i];
        
        [self deletePhoto:photoId];
        
        while ([self isRunning]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        }
    }
}

-(void)deletePhoto:(NSString*) photoId {
    NSLog(@"- Deleting %@", photoId);
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            photoId, @"photo_id",
                            nil];
    
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photos.delete" arguments:params];
}

- (RACSignal*)searchImagesPage:(int)pageNo {
    
    NSDictionary *searchParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                 // @"iphoto2flickr:", @"machine_tags", // This skips images that should be returned?!?
                                  @"last_update, tags, description", @"extras", // TODO check what does extras = machine_tags return?
                                  @"me", @"user_id",
                                  @"500", @"per_page",
                                  [NSString stringWithFormat:@"%d", pageNo], @"page",
                                  nil];
    
    _flickrRequest.sessionInfo = kSignalOperation;
    [_flickrRequest callAPIMethodWithGET:@"flickr.photos.search" arguments:searchParams];
    return [self createOperationSignal];
}


#pragma mark Photosets ---------------------------------------------------------------------------------

-(void)readAllPhotosetsWithDescriptionPrefix:(NSString*) descriptionPrefix {
    
    _mapAlbumIdentifierToFlickrPhotoset = [[NSMutableDictionary alloc]init];
        
    NSArray* allFlickrPhotosets = [self getAllPhotosets];
    
    for (NSDictionary* flickrPhotoset in allFlickrPhotosets) {
        NSString *photosetDescription = [[flickrPhotoset objectForKey:@"description"] objectForKey:@"_text"];
        
        NSString *albumIdentifier = nil;
        if ([photosetDescription hasPrefix:descriptionPrefix]) {
            albumIdentifier = [photosetDescription substringFromIndex:[descriptionPrefix length]];
            [_mapAlbumIdentifierToFlickrPhotoset setObject:flickrPhotoset forKey:albumIdentifier];
        }
    }
}

- (void)setFlickrPhotosetId:(NSString*)flickrPhotosetId forMediaGroupIdentifier:(NSString*)mediaGroupIdentifier {
    NSDictionary *flickrPhotoset = [NSDictionary dictionaryWithObject:flickrPhotosetId
                                                               forKey:@"id"];
    [_mapAlbumIdentifierToFlickrPhotoset setObject:flickrPhotoset forKey:mediaGroupIdentifier];
}

- (NSDictionary*)getFlickrPhotosetForIdentifier:(NSString*)identifier {
    return [_mapAlbumIdentifierToFlickrPhotoset objectForKey:identifier];
}

- (NSString*)getFlickrPhotosetIdForIdentifier:(NSString*)identifier {
    return [[self getFlickrPhotosetForIdentifier:identifier] objectForKey:@"id"];
}

- (BOOL)flickrPhotosetForIdentifier:(NSString*)identifier hasLastChangedBeforeModificationDate:(NSDate*)modificationDate {
    NSDictionary *flickrPhotoset = [self getFlickrPhotosetForIdentifier:identifier];
    NSString *flickrLastUpdateAsString = [flickrPhotoset objectForKey:@"date_update"];
    NSTimeInterval flickrLastUpdateAsDouble = [flickrLastUpdateAsString doubleValue];
    NSDate *flickrLastUpdate = [NSDate dateWithTimeIntervalSince1970:flickrLastUpdateAsDouble];
    
    if ([flickrLastUpdate compare:modificationDate] == NSOrderedAscending) {
        // flickrLastUpdate is earlier than modificationDate
        return true;
    }
    
    return false;
}

- (int)getObjectCountOfFlickrPhotosetForIdentifier:(NSString*)identifier {
    NSDictionary *flickrPhotoset = [self getFlickrPhotosetForIdentifier:identifier];
    int photosCount = [[flickrPhotoset objectForKey:@"photos"] intValue];
    int videosCount = [[flickrPhotoset objectForKey:@"videos"] intValue];
    return photosCount + videosCount;
}

/** private */
- (NSArray*)getAllPhotosets {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            nil];
    
    [_flickrRequest callAPIMethodWithGET:@"flickr.photosets.getList" arguments:params];
    
    while ([self isRunning]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
    
    NSDictionary *photosetsDict = [_responseDict objectForKey:@"photosets"];
    NSArray *photosetsArray = [photosetsDict objectForKey:@"photoset"];
    return photosetsArray;
}

- (RACSignal*)createPhotosetTitle:(NSString*)title description:(NSString*)description primaryPhotoId:(NSString*)primaryPhotoId {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            description, @"description",
                            title, @"title",
                            primaryPhotoId, @"primary_photo_id",
                            nil];
    
   _flickrRequest.sessionInfo = kSignalOperation;
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photosets.create" arguments:params];
    return [self createOperationSignal];
}

-(NSString*)getCreatedPhotosetId {
    NSDictionary *photosetDict = [_responseDict objectForKey:@"photoset"];
    NSString *photosetId = [photosetDict objectForKey:@"id"];
    return photosetId;
}

-(RACSignal*)editPhotoset:(NSString*)photosetId primaryPhotoId:(NSString*)primaryPhotoId photoIds:(NSString*)photoIds {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            photosetId, @"photoset_id",
                            primaryPhotoId, @"primary_photo_id",
                            photoIds, @"photo_ids",
                            nil];
    
    _flickrRequest.sessionInfo = kSignalOperation;
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photosets.editPhotos" arguments:params];
    return [self createOperationSignal];
}

-(RACSignal*)editPhotoset:(NSString*)photosetId title:(NSString*)title {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            photosetId, @"photoset_id",
                            title, @"title",
                            nil];
    
    _flickrRequest.sessionInfo = kSignalOperation;
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photosets.editMeta" arguments:params];
    return [self createOperationSignal];
}

@end
