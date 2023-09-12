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

NS_ASSUME_NONNULL_BEGIN

@interface NRMAEventManager : NSObject

- (instancetype)init;
- (void)setMaxEventBufferSize:(NSUInteger)size;
- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds;
- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds;
- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event;
- (void)empty;
- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error clearEvents:(BOOL)clearEvents;
@end

NS_ASSUME_NONNULL_END
