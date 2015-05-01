#import <Foundation/Foundation.h>
@import MediaLibrary;

@interface P2FMediaGroup : NSObject
-(id)initWithMediaGroup:(MLMediaGroup*) mediaGroup;
-(NSString*)name;
-(NSString*)identifier;
-(NSArray*)mediaObjectsIdentifiers;
-(NSString*)keyPhotoIdentifier;
-(NSDate*)modificationDate;
@end
