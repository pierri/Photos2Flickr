#import <Foundation/Foundation.h>
#import "P2FOperation.h"
#import "PhotosClient.h"
#import "P2FMediaGroup.h"

@interface P2FMediaGroupOperation : P2FOperation

@property (nonatomic) P2FMediaGroup *mediaGroup;

- (id)initWithMediaGroup:(P2FMediaGroup*) mediaGroup;

@end
