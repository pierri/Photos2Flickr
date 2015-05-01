#import "P2FAppDelegate.h"

@interface P2FAppDelegate()
@property Photos2Flickr *photos2flickr;
@end

@implementation P2FAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"", @"apiKey",
                                 @"", @"apiSecret",
                                 nil];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:appDefaults];

    
    // TODO prompt user for API key and secret on first run
    [defaults setValue:@"9a03d61810ff38c6d52a4cec1ceea0b4" forKey:@"apiKey"];
    [defaults setValue:@"7bf705484f3e8d11" forKey:@"apiSecret"];
    
    // TODO if called with --reset:
    // [defaults setValue:@"" forKey:@"apiKey"];
    // [defaults setValue:@"" forKey:@"apiSecret"];
    
    NSString *apiKey = [defaults valueForKey:@"apiKey"];
    NSString *secret = [defaults valueForKey:@"apiSecret"];
    
    [FlickrClient createWithAPIKey:apiKey secret:secret];
    
    FlickrClient *flickrClient = [FlickrClient sharedClient];
    
    // TODO if called with --reset:
    //[flickrClient deauthorize];
    
    if (![flickrClient isAuthorized]) {
        [flickrClient requestAuthorization];
    }
    
    _photos2flickr = [[Photos2Flickr alloc]init];
    _photos2flickr.flickrClient = flickrClient;
    _photos2flickr.delegate = _menulet;
    
    [self startProcessing];
}

-(void)startProcessing{
    [_photos2flickr uploadMedia];
}

-(void)stopProcessing{
    [_photos2flickr.flickrClient stopProcessing];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [[NSAppleEventManager sharedAppleEventManager]
     setEventHandler:self
     andSelector:@selector(handleURLEvent:withReplyEvent:)
     forEventClass:kInternetEventClass
     andEventID:kAEGetURL];
}

- (void)handleURLEvent:(NSAppleEventDescriptor*)event
        withReplyEvent:(NSAppleEventDescriptor*)replyEvent
{
    NSString* url = [[event paramDescriptorForKeyword:keyDirectObject]
                     stringValue];
    NSLog(@"%@", url);
    
    // photos2flickr://verifyFlickrAuthorization?oauth_token=72157653034988676-cc23d1d2e2997578&oauth_verifier=ab68782106ce61ed
    
    NSString *kOAuthVerifier = @"oauth_verifier=";
    
    if ([url hasPrefix:kFlickrClientOAuthCallbackURL]
        && [url containsString:kOAuthVerifier]) {
        NSRange range = [url rangeOfString:kOAuthVerifier];
        int verifierIndex = range.location + [kOAuthVerifier length];
        NSString *oAuthVerifierToken = [url substringFromIndex:verifierIndex];
        NSLog(@"%@", oAuthVerifierToken);
        
        FlickrClient *flickrClient = [FlickrClient sharedClient];
        [flickrClient verifyAuthorizationWithToken: oAuthVerifierToken];

    }
    
}

@end
