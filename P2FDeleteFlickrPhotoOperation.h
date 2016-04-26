#import <Foundation/Foundation.h>
#import "P2FOperation.h"

@interface P2FDeleteFlickrPhotoOperation : P2FOperation
@property (nonatomic) NSString *flickrPhotoId;
- (id)initWithFlickrPhotoId:(NSString *) flickrPhotoId;
@end
