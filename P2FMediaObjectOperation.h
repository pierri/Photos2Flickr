#import <Foundation/Foundation.h>
#import "P2FOperation.h"
#import "PhotosClient.h"
#import "P2FMediaObject.h"


@interface P2FMediaObjectOperation  : P2FOperation

@property (nonatomic) P2FMediaObject *mediaObject;

- (id)initWithMediaObject:(P2FMediaObject*) mediaObject;

@end
