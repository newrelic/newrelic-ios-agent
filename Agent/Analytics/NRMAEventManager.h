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
#import "PersistentEventStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAEventManager : NSObject

- (void)setMaxEventBufferSize:(NSUInteger)size;
- (NSUInteger)getMaxEventBufferSize;
- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds;
- (NSUInteger)getMaxEventBufferTimeInSeconds;
- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds;
- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event;
- (void)empty;
- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error clearEvents:(BOOL)clearEvents;

+ (NSString *)getLastSessionEventsString;
+ (NSMutableArray<NRMAAnalyticEventProtocol> *)getLastSessionEventsArray;
+ (void) clearDuplicationStores;
+ (nullable NSString *)getLastSessionEventsFromFilename:(NSString *)filename;
@end

NS_ASSUME_NONNULL_END
