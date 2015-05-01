#import <Foundation/Foundation.h>
@import MediaLibrary;

@interface P2FMediaObject : NSObject
- (id)initWithMediaObject:(MLMediaObject*) mediaObject;
-(NSString*)identifier;
-(NSString*)title;
-(NSString*)description;
-(NSURL*)url;
-(NSArray*)facesNames;
-(NSUInteger)fileSize;
-(NSDate*)modificationDate;
-(NSString*)machineTag;

@end