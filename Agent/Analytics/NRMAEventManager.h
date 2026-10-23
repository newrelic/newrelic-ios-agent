//
//  NRMAEventManager.h
//  Agent
//
//  Created by Steve Malsam on 6/7/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAAnalyticEventProtocol.h"
#import "NRMANetworkResponseData.h"
#import "NRMANetworkRequestData.h"
#import "NRMAPayload.h"
#import "NRMASAM.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAEventManager : NSObject

// Source of the "mutableAttributesSnapshot" captured for event persistence at
// write time. Weak + settable (not a constructor param) so existing callers
// (including tests) that construct an NRMAEventManager without one keep
// working -- persistence of the snapshot is simply skipped (empty) until set.
@property (nonatomic, weak, nullable) NRMASAM *sessionAttributeManager;

- (void)setMaxEventBufferSize:(NSUInteger)size;
- (NSUInteger)getMaxEventBufferSize;
- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds;
- (NSUInteger)getMaxEventBufferTimeInSeconds;
- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds;
- (BOOL)didExceedMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds;
- (NSUInteger)getEventsRecordedCount;
- (NSUInteger)getEventsEvictedCount;
- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event;
- (void)empty;
- (void)resetTimestamp;
- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error clearEvents:(BOOL)clearEvents;

@end

NS_ASSUME_NONNULL_END
