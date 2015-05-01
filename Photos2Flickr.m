#import "Photos2Flickr.h"
#import "P2FMediaObject.h"
#import "P2FUploadMediaObjectOperation.h"
#import "P2FUpdateMediaObjectOperation.h"
#import "P2FCreateMediaGroupOperation.h"
#import "P2FUpdateMediaGroupPicsOperation.h"
#import "Underscore.h"
#define _ Underscore

@interface Photos2Flickr()

@property NSMutableArray *operations;
@property NSUInteger totalBytesToUpload;
@property NSUInteger totalBytesDone;
@end

@implementation Photos2Flickr

-(id)init {
    self = [super init];
    self.operations = [[NSMutableArray alloc]init];
    return self;
}

-(void) uploadMedia {
    [_delegate processStarting];
    
    
    [_flickrClient readAllImagesWithMachineTag:kMachineTagPrefix];
    
    [_flickrClient readAllPhotosetsWithDescriptionPrefix:kMachineTagPrefix];
    
    
    //NSLog(@"Loading media objects");
    
    PhotosClient *photosClient = [[PhotosClient alloc] init];
    
    RACSignal *mediaObjectsOperationsSignal = [[[photosClient loadMediaObjects]
                                                map:self.wrapInP2FMediaObject]
                                               map:self.determineMediaObjectOperation];
    
    RACSignal *mediaGroupsOperationsSignal = [[[[photosClient loadMediaGroups]
                                               map:self.wrapInP2FMediaGroup]
                                              map:self.determineMediaGroupOperations]
                                              flatten];
    
    
    RACSignal *operationsSignal = [[mediaObjectsOperationsSignal
                                   concat:mediaGroupsOperationsSignal]
                                   filter:self.removeNil];
    
    RACSignal *operationsReplaySignal = [operationsSignal replay];
    
    [[operationsSignal aggregateWithStart:@0 reduce:self.addOperationSize]
     subscribeNext:^(NSNumber *totalBytesToUpload) {
         
         _totalBytesToUpload = [totalBytesToUpload unsignedIntegerValue];
         _totalBytesDone = 0;
         [self.delegate progressBytesUploaded:_totalBytesDone totalBytesToUpload:_totalBytesToUpload];
         NSLog(@"%@ to upload overall", [self sizeHumanReadable:[totalBytesToUpload unsignedIntegerValue]]);
     
         [[operationsReplaySignal zipWith:_flickrClient.ready] subscribeNext:^(RACTuple *tuple) {
             P2FOperation *operation = [tuple objectAtIndex:0];
             NSString *operationDescription = [operation description];
             NSUInteger operationSize = [operation getSizeBytes];
             
             [self operationProgress:operationDescription bytesDone:0 ofSizeBytes:@(operationSize)];
             
             RACSignal *executionSignal = [operation execute];
             
             [executionSignal subscribeNext:^(NSNumber *bytesSentNumber) {
                 [self operationProgress:operationDescription bytesDone:bytesSentNumber ofSizeBytes:@(operationSize)];
             } completed:^{
                 _totalBytesDone += operationSize;
             }];
         } completed:^{
             NSLog(@"Processing done or interrupted");
             [_delegate processInterrupted];
         }];
         
         [_flickrClient startProcessing];
     }];
}

- (UnderscoreArrayMapBlock)wrapInP2FMediaObject {
    return ^P2FMediaObject* (MLMediaObject* mediaObject) {
        return [[P2FMediaObject alloc]initWithMediaObject:mediaObject];
    };
}

- (UnderscoreArrayMapBlock)wrapInP2FMediaGroup {
    return ^P2FMediaGroup* (MLMediaGroup* mediaGroup) {
        return [[P2FMediaGroup alloc]initWithMediaGroup:mediaGroup];
    };
}

- (UnderscoreArrayMapBlock)determineMediaObjectOperation {
    return ^NSObject<P2FOperation>* (P2FMediaObject* mediaObject) {
        P2FOperation* operation = nil;
                
        if (![self objectExistsOnFlickr:mediaObject]) {
            operation = [[P2FUploadMediaObjectOperation alloc]initWithMediaObject:mediaObject];
        } else if ([self wasEditedSinceLastFlickrUpload:mediaObject]) {
            // operation = [[P2FUpdateMediaObjectOperation alloc]initWithMediaObject:mediaObject];
        }
        return operation;
    };
}

- (UnderscoreArrayMapBlock)determineMediaGroupOperations {
    return ^RACSignal* (P2FMediaGroup* p2fMediaGroup) {
        
        RACSignal *operationsSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            
            BOOL justCreated = false;
            if (![self groupExistsOnFlickr:p2fMediaGroup]) {
                justCreated = true;
                [subscriber sendNext:[[P2FCreateMediaGroupOperation alloc]initWithMediaGroup:p2fMediaGroup]];
            }
            
            if (justCreated || [self groupWasEditedSinceLastFlickrUpload:p2fMediaGroup]) {
                [subscriber sendNext:[[P2FUpdateMediaGroupPicsOperation alloc]initWithMediaGroup:p2fMediaGroup]];
            }
    
            [subscriber sendCompleted];
            
            return nil;
        }];
        
        return operationsSignal;
    };
}

-(UnderscoreTestBlock) removeNil {
    return ^BOOL (id value) {
        return value != nil;
    };
}

- (BOOL)objectExistsOnFlickr:(P2FMediaObject*) mediaObject {
    NSString *photosMediaObjectIdentifier = [mediaObject identifier];
    NSString *flickrPhotoId = [_flickrClient getFlickrPhotoIdForRawIdentifier:photosMediaObjectIdentifier];
    if (flickrPhotoId != nil) {
        return true;
    }
    return false;
}

- (BOOL)groupExistsOnFlickr:(P2FMediaGroup*) mediaGroup {
    NSString *photosMediaGroupIdentifier = [mediaGroup identifier];
    NSDictionary *flickrPhotoset = [_flickrClient getFlickrPhotosetForIdentifier:photosMediaGroupIdentifier];
    if (flickrPhotoset != nil) {
        return true;
    }
    return false;
}

-(BOOL)wasEditedSinceLastFlickrUpload:(P2FMediaObject*)mediaObject {
    NSString *photosMediaObjectIdentifier = [mediaObject identifier];
    
    NSDate *photosMediaObjectModificationDate = [mediaObject modificationDate];
    
    return [_flickrClient flickrPhotoForRawIdentifier:photosMediaObjectIdentifier hasLastChangedBeforeModificationDate:photosMediaObjectModificationDate];
}


- (BOOL)groupWasEditedSinceLastFlickrUpload:(P2FMediaGroup*)mediaGroup {
    NSString *photosMediaGroupIdentifier = [mediaGroup identifier];

    NSDate *photosMediaGroupModificationDate = [mediaGroup modificationDate];
    
    if ([_flickrClient flickrPhotosetForIdentifier:photosMediaGroupIdentifier hasLastChangedBeforeModificationDate:photosMediaGroupModificationDate]) {
        return true;
    }
    
    if ([_flickrClient getObjectCountOfFlickrPhotosetForIdentifier:photosMediaGroupIdentifier]
        != [[mediaGroup mediaObjectsIdentifiers] count]) {
        return true;
    }
    
    return false;

}

- (UnderscoreArrayIteratorBlock)executeOperation {
    return ^(NSObject<P2FOperation>* operation) {
        [operation execute];
    };
}

/** private */
-(void)operationProgress:(NSString*)operationDescription bytesDone:(NSNumber*)bytesSentNumber ofSizeBytes:(NSNumber*)operationSizeBytesNumber {
    
    NSUInteger bytesSent = [bytesSentNumber unsignedIntegerValue];
    NSUInteger sizeBytes = [operationSizeBytesNumber unsignedIntegerValue];
    
    int percent = 0;
    if (_totalBytesToUpload != 0) {
        percent = ((_totalBytesDone + bytesSent) * 100 ) / _totalBytesToUpload;
    }
    
    NSLog(@"%@: %@ of %@ done (overall %d %% done)",
          operationDescription,
          [self sizeHumanReadable:bytesSent],
          [self sizeHumanReadable:sizeBytes],
          percent);

    [self.delegate progressBytesUploaded:(_totalBytesDone + bytesSent) totalBytesToUpload:_totalBytesToUpload];
}

- (UnderscoreReduceBlock) addOperationSize {
    return ^NSNumber* (NSNumber* memo, P2FOperation* operation) {
        NSUInteger operationSize = [operation getSizeBytes];
        return @([memo unsignedIntegerValue] + operationSize);
    };
}

- (UnderscoreReduceBlock) addOperationDone {
    return ^NSNumber* (NSNumber* memo, P2FOperation* operation) {
        NSUInteger operationDone = [operation getBytesDone];
        return @([memo unsignedIntegerValue] + operationDone);
    };
}

-(NSString*) sizeHumanReadable: (NSUInteger*)byteCountInteger {
    NSString *sizeHumanReadable = [NSByteCountFormatter stringFromByteCount:byteCountInteger  countStyle:NSByteCountFormatterCountStyleFile];
    
    return sizeHumanReadable;
}

@end
