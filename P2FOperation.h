#import <Foundation/Foundation.h>
#import "P2FMediaObject.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "FlickrClient.h"

/// Operations are used for progress computation:
/// * Goal: Progress indication with time remaining (e.g. 1:20 hour remaining)
/// * Assumption: Stable network connection
/// * Percent indication over total size in MB
/// * Use pic size in MB
/// * Consider a constant request size (e.g. 0.05 MB) for all other requests
/// * Display "Estimating time remaining" until first MB uploaded
/// * Time remaining is computed using average throughput during time elapsed

@protocol P2FOperation <NSObject>
-(RACSignal*)execute;
-(NSUInteger)getSizeBytes;
@end

@interface P2FOperation : NSObject <P2FOperation>

@end
