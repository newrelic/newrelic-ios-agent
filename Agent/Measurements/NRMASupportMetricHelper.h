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
+ (void) enqueueSessionReplayConfigEnabledMetric:(BOOL)enabled;
+ (void) enqueueSessionReplayConfigSamplingRateMetric:(double)samplingRate;
+ (void) enqueueSessionReplayConfigErrorSamplingRateMetric:(double)errorSamplingRate;

+ (void) enqueueJSErrorUploadTimeMetric:(double)milliseconds;
+ (void) enqueueJSErrorUploadTimeoutMetric;
+ (void) enqueueJSErrorUploadThrottledMetric;
+ (void) enqueueJSErrorFailedUploadMetric;

@end
