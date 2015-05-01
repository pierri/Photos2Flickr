#import "P2FMenulet.h"
#import "P2FAppDelegate.h"

static double const SECOND = 1;
static double const MINUTE = 60 * SECOND;
static double const HOUR = 60 * MINUTE;
static double const DAY = 24 * HOUR;

@interface P2FMenulet()

@property NSTimeInterval startTimeStamp;
@property double timeRemaining;
@property P2FAppDelegate *appDelegate;

@property NSMenuItem *lastUploadLabel;
@property NSMenuItem *lastUploadTime;
@property NSMenuItem *timeRemainingLabel;
@property NSMenuItem *timeRemainingDisplay;
@property NSMenuItem *computingTimeRemaining;
@property NSMenuItem *uploadNowButton;
@property NSMenuItem *stopUploadingButton;
@property NSMenuItem *openPreferencesButton;

@end

@implementation P2FMenulet {
    __weak IBOutlet NSMenu *menuletMenu;
}

- (void) awakeFromNib {
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[statusItem setHighlightMode:YES];
	[statusItem setEnabled:YES];
	[statusItem setToolTip:@"Photos to Flickr"];
	
	[statusItem setTarget:self];
    
    [statusItem setMenu:menuletMenu];
    
    _lastUploadLabel = [menuletMenu itemAtIndex:0];
    _lastUploadTime = [menuletMenu itemAtIndex:1];
    _timeRemainingLabel = [menuletMenu itemAtIndex:2];
    _timeRemainingDisplay = [menuletMenu itemAtIndex:3];
    _computingTimeRemaining = [menuletMenu itemAtIndex:4];
    _uploadNowButton = [menuletMenu itemAtIndex:6];
    _stopUploadingButton = [menuletMenu itemAtIndex:7];
    _openPreferencesButton = [menuletMenu itemAtIndex:9];
    
    [_openPreferencesButton setHidden:true]; // TODO create preferences pane
		
    NSImage *menuIcon;
    if ([[[NSAppearance currentAppearance] name] containsString:NSAppearanceNameVibrantDark]) {
        // Dark menu bar
        menuIcon = [NSImage imageNamed:@"MenuletIconInvert"];
    } else {
        // Light menu bar
        menuIcon = [NSImage imageNamed:@"MenuletIcon"];
    }
    [statusItem setImage:menuIcon];
    
    _appDelegate = (P2FAppDelegate*)[[NSApplication sharedApplication]delegate];
    _appDelegate.menulet = self;
}

- (IBAction) onPressUploadNow:(id)sender {
    [_appDelegate startProcessing];
}

- (IBAction) onPressStopUploading:(id)sender {
    [_appDelegate stopProcessing];
}

- (IBAction) onPressOpenPreferences:(id)sender {
    NSLog(@"Menu item clicked");
    
}

-(void)processStarting {
    _startTimeStamp = 0;
    _timeRemaining = 0;
    [self toggleButtonsUploadInProgress:true];
}

-(void)progressBytesUploaded:(NSUInteger)bytesUploaded totalBytesToUpload:(NSUInteger)bytesToUpload {
   
    if (bytesUploaded == 0 || !self.startTimeStamp) { // starting
        _startTimeStamp = [[NSDate date] timeIntervalSince1970];
        
    } else if (bytesUploaded != bytesToUpload) { // in progress
        _timeRemaining = [self computeTimeRemainingBytesUploaded:bytesUploaded totalBytesToUpload: bytesToUpload];
        [self displayTimeRemaining:_timeRemaining];
        [self toggleButtonsUploadInProgress:true];

    } else { // completed
        [self toggleButtonsUploadInProgress:false];
    }
}

-(void)processInterrupted {
    [self toggleButtonsUploadInProgress:false];
}

/// See also P2FOperation.h for information about progress computation
-(double) computeTimeRemainingBytesUploaded:(NSUInteger)bytesUploaded totalBytesToUpload:(NSUInteger)bytesToUpload {
    NSTimeInterval currentTimeStamp = [[NSDate date] timeIntervalSince1970];
    double timeElapsed = currentTimeStamp - self.startTimeStamp;
    double timeRemaining = timeElapsed * bytesToUpload / bytesUploaded;
    return timeRemaining;
}

-(void) displayTimeRemaining:(double)timeRemaining {
    NSDateComponentsFormatter* remainingFormatter = [[NSDateComponentsFormatter alloc] init];
    remainingFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    remainingFormatter.includesTimeRemainingPhrase = YES;
    
    if (timeRemaining > 5 * DAY) {
        remainingFormatter.allowedUnits = NSCalendarUnitMonth | NSCalendarUnitDay;
    } else if (timeRemaining > 1 * DAY) {
        remainingFormatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour;
    } else if (timeRemaining > 5 * HOUR) {
        remainingFormatter.allowedUnits = NSCalendarUnitHour;
    } else if (timeRemaining > 5 * MINUTE) {
        remainingFormatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    } else {
        remainingFormatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    }
    
    NSString* timeRemainingString = [remainingFormatter stringFromTimeInterval:timeRemaining];
    
    [_timeRemainingDisplay setTitle:timeRemainingString];
}

-(void)toggleButtonsUploadInProgress:(BOOL)uploadInProgress {
    [_lastUploadLabel setHidden:uploadInProgress];
    [_lastUploadTime setHidden:uploadInProgress];
    [_timeRemainingLabel setHidden:!uploadInProgress];
    
    [_timeRemainingDisplay setHidden:(!uploadInProgress) || (!_timeRemaining)];
    [_computingTimeRemaining setHidden:(!uploadInProgress) || (_timeRemaining)];
    
    [_uploadNowButton setHidden:uploadInProgress];
    [_stopUploadingButton setHidden:!uploadInProgress];
}

@end
