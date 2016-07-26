#import <Foundation/Foundation.h>
#import <ReactiveCocoa.h>

@interface FlickrClient : NSObject

@property (nonatomic, assign, readonly, getter = isAuthorized) BOOL authorized;
@property (nonatomic) NSMutableDictionary* mapCleanIdentifierToFlickrPhoto;
@property (nonatomic) NSMutableDictionary* mapAlbumIdentifierToFlickrPhotoset;
@property (nonatomic) RACSignal *ready;

#pragma mark Initialization
+ (instancetype)createWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
+ (instancetype)sharedClient;

#pragma mark Authorization
- (BOOL)isAuthorized;
- (void)requestAuthorization;
- (BOOL)verifyAuthorizationWithToken:(NSString *)verifierToken;
- (void)deauthorize;

#pragma mark Upload
- (RACSignal*)uploadImage:(NSURL *)inImageURL title:(NSString*)title description:(NSString*)description facesNames:(NSArray*)facesNames machineTag:(NSString*)machineTag;
- (RACSignal*)replaceImage:(NSURL *)inImageURL photoId:(NSString*)photoId;
- (void)startProcessing;
- (void)stopProcessing;
- (NSString*)getUploadedPhotoId;

#pragma mark Photos
- (RACSignal*)readAllImagesWithMachineTag:(NSString*)machineTagPrefix;
- (void)setFlickrPhotoId:(NSString*)flickrPhotoId forRawIdentifier:(NSString*)rawIdentifier;
- (NSString*)getFlickrPhotoIdForRawIdentifier:(NSString*)rawIdentifier;
- (BOOL)flickrPhotoForRawIdentifier:(NSString*)rawIdentifier hasLastChangedBeforeModificationDate:(NSDate*)modificationDate;
-(RACSignal*)deletePhoto:(NSString*) photoId;

#pragma mark Helpers
+ (NSString*)cleanTag:(NSString*)rawTag;

#pragma mark Photosets
- (void)readAllPhotosetsWithDescriptionPrefix:(NSString*)descriptionPrefix;
- (void)setFlickrPhotosetId:(NSString*)flickrPhotosetId forMediaGroupIdentifier:(NSString*)mediaGroupIdentifier;
- (NSDictionary*)getFlickrPhotosetForIdentifier:(NSString*)identifier;
- (NSString*)getFlickrPhotosetIdForIdentifier:(NSString*)identifier;
- (BOOL)flickrPhotosetForIdentifier:(NSString*)identifier hasLastChangedBeforeModificationDate:(NSDate*)modificationDate;
- (int)getObjectCountOfFlickrPhotosetForIdentifier:(NSString*)identifier;
- (RACSignal*)createPhotosetTitle:(NSString*)title description:(NSString*)description primaryPhotoId:(NSString*)primaryPhotoId;
- (NSString*)getCreatedPhotosetId;
- (RACSignal*)editPhotoset:(NSString*)photosetId primaryPhotoId:(NSString*)primaryPhotoId photoIds:(NSString*)photoIds;
- (RACSignal*)editPhotoset:(NSString*)photosetId title:(NSString*)title;

@end

static NSString * const kFlickrClientOAuthCallbackURL = @"photos2flickr://verifyFlickrAuthorization";
