//
//  NRMASupportMetricHelper.h
//  Agent
//
//  Created by Chris Dillard on 7/12/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewRelicFeatureFlags.h"

static NSMutableArray *deferredMetrics;

@interface NRMASupportMetricHelper : NSObject
+ (void) enqueueDataUseMetric:(NSString*)subDestination size:(long)size received:(long)received;
+ (void) enqueueFeatureFlagMetric:(BOOL)enabled features:(NRMAFeatureFlags)features;
+ (void) enqueueInstallMetric;
+ (void) enqueueMaxPayloadSizeLimitMetric:(NSString*)endpoint;
+ (void) enqueueUpgradeMetric;
+ (void) enqueueStopAgentMetric;
+ (void) enqueueConfigurationUpdateMetric;
+ (void) enqueueRateLimitBackoffMetric:(NSTimeInterval)backoffSeconds;
+ (void) enqueueBufferPoolSizeConfiguration:(unsigned int)size;
+ (void) enqueueMaxBufferTimeConfiguration:(unsigned int)seconds;
+ (void) enqueue4HourSessionRestartMetric;

+ (void) processDeferredMetrics;
+ (void) enqueueOfflinePayloadMetric:(long)size;

+ (void) enqueueLogSuccessMetric:(long)size;
+ (void) enqueueLogFailedMetric;

+ (void) enqueueSessionReplaySuccessMetric:(long)size;
+ (void) enqueueSessionReplayFailedMetric;
+ (void) enqueueSessionReplayURLTooLargeMetric;
// One replay event over the payload cap on its own was broken into several smaller events.
+ (void) enqueueSessionReplayEventPaginatedMetric;
+ (void) enqueueSessionReplayConfigEnabledMetric:(BOOL)enabled;
+ (void) enqueueSessionReplayConfigSamplingRateMetric:(double)samplingRate;
+ (void) enqueueSessionReplayConfigErrorSamplingRateMetric:(double)errorSamplingRate;

+ (void) enqueueJSErrorUploadTimeMetric:(double)milliseconds;
+ (void) enqueueJSErrorUploadTimeoutMetric;
+ (void) enqueueJSErrorUploadThrottledMetric;
+ (void) enqueueJSErrorFailedUploadMetric;

+ (void) enqueueRetrySuccessMetric:(NSString*)endpoint;
+ (void) enqueueRetryFailedMetric:(NSString*)endpoint;

+ (void) enqueueKMMDetectionMetric;

// WebView session replay: suffix is appended to kNRMAWebViewReplayMetricPrefix, e.g. @"Injected".
+ (void) enqueueWebViewReplayMetric:(NSString*)suffix;

// Events (queue lifecycle) supportability metrics -- Android parity (NR-478730)
+ (void) enqueueEventAddedMetric;
+ (void) enqueueEventOverflowMetric;
+ (void) enqueueEventEvictedMetric;
+ (void) enqueueEventQueueSizeExceededMetric;
+ (void) enqueueEventQueueTimeExceededMetric;
+ (void) enqueueEventRecordedMetric:(NSUInteger)recorded evicted:(NSUInteger)evicted;
+ (void) enqueueEventSizeUncompressedMetric:(long)size;

@end
