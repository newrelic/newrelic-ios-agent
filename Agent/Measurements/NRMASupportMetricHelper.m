//
//  NRMASupportMetricHelper.m
//  Agent
//
//  Created by Chris Dillard on 7/12/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMASupportMetricHelper.h"
#import "NewRelicInternalUtils.h"
#import "NRMAMeasurements.h"
#import "NRMATaskQueue.h"
#import "NRMAFlags.h"
#import "NRMAStartTimer.h"

@implementation NRMASupportMetricHelper

static NSMutableArray<NRMAMetric *> *deferredMetrics;

+ (void) initialize {
    deferredMetrics = [NSMutableArray array];
}

// The value _additionalValue being non-nil means that this is a Data Usage Supportability Metric.
+ (void) enqueueDataUseMetric:(NSString*)subDestination size:(long)size received:(long)received {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRMABytesOutSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, subDestination]
                                                    value:[NSNumber numberWithLongLong:size]
                                                    scope:@""
                                          produceUnscoped:YES
                                          additionalValue:[NSNumber numberWithLongLong:received]]];
}

+ (void) enqueueFeatureFlagMetric:(BOOL)enabled features:(NRMAFeatureFlags)features {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    for (NSString *name in [NRMAFlags namesForFlags:features]) {
        NSString* featureFlagString = [NSString stringWithFormat:@"Supportability/Mobile/%@/%@/API/%@/%@",
                                       nativePlatform, kPlatformPlaceholder, enabled ? @"enableFeature" : @"disableFeature", name];
        @synchronized (deferredMetrics) {
            [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:featureFlagString
                                                                  value:[NSNumber numberWithLongLong:1]
                                                                  scope:@""
                                                        produceUnscoped:YES
                                                        additionalValue:nil]];
        }
    }
}

+ (void) enqueueInstallMetric {
    @synchronized (deferredMetrics) {
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:kNRMAAppInstallMetric
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueMaxPayloadSizeLimitMetric:(NSString*)endpoint {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, endpoint]
                                                    value:@1
                                                    scope:nil]];
}

+ (void) enqueueOfflinePayloadMetric:(long)size {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMAOfflineSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest]
                                                    value:[NSNumber numberWithLongLong:size]
                                                    scope:nil]];
}

+ (void) enqueueUpgradeMetric {
    @synchronized (deferredMetrics) {
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:kNRMAAppUpgradeMetric
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueStopAgentMetric {
    NSString* metricString = [NSString stringWithFormat:kNRMAStopAgentMetricFormatString, [NewRelicInternalUtils osName], kPlatformPlaceholder];
    @synchronized (deferredMetrics) {
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:metricString
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueConfigurationUpdateMetric {
    NSString* metricString = [NSString stringWithFormat:kNRMAConfigurationUpdated, [NewRelicInternalUtils osName], kPlatformPlaceholder];
    @synchronized (deferredMetrics) {
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:metricString
                                                              value:@1
                                                              scope:nil]];
    }
}

// Logging

+ (void) enqueueLogSuccessMetric:(long)size {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRMALoggingMetricSuccessfulSize, nativePlatform, platform]
                                                    value:[NSNumber numberWithLongLong:size]
                                                    scope:@""
                                          produceUnscoped:YES
                                          additionalValue:nil]];
}

+ (void) enqueueLogFailedMetric {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMALoggingMetricFailedUpload, nativePlatform, platform]
                                                    value:@1
                                                    scope:nil]];

}

// End Logging

// Session Replay
+ (void) enqueueSessionReplaySuccessMetric:(long)size {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRMASessionReplayMetricSuccessfulSize, nativePlatform, platform]
                                                    value:[NSNumber numberWithLongLong:size]
                                                    scope:@""
                                          produceUnscoped:YES
                                          additionalValue:nil]];
}

+ (void) enqueueSessionReplayFailedMetric {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMASessionReplayMetricFailedUpload, nativePlatform, platform]
                                                    value:@1
                                                    scope:nil]];
}

+ (void) enqueueSessionReplayURLTooLargeMetric {
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMASessionReplayMetricURLTooLarge, nativePlatform, platform]
                                                    value:@1
                                                    scope:nil]];
}

+ (void) processDeferredMetrics {
    // Handle any deferred app start metrics
    if ([[NRMAStartTimer sharedInstance] appLaunchDuration] != 0) {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:NRMA_METRIC_APP_LAUNCH_COLD
                                                        value:[NSNumber numberWithDouble:[[NRMAStartTimer sharedInstance] appLaunchDuration]]
                                                        scope:@""
                                              produceUnscoped:YES
                                              additionalValue:nil]];
        [NRMAStartTimer sharedInstance].appLaunchDuration = 0;
    }

    if ([[NRMAStartTimer sharedInstance] appResumeDuration] != 0) {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:NRMA_METRIC_APP_LAUNCH_RESUME
                                                        value:[NSNumber numberWithDouble:[[NRMAStartTimer sharedInstance] appResumeDuration]]
                                                        scope:@""
                                              produceUnscoped:YES
                                              additionalValue:nil]];
        [NRMAStartTimer sharedInstance].appResumeDuration = 0;
    }

    // Handle any deferred supportability metrics.
    @synchronized (deferredMetrics) {
        for (NRMAMetric *metric in deferredMetrics) {
            NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
            NSString *deferredMetricName = metric.name;

            if ([metric.name containsString:kPlatformPlaceholder]) {
                deferredMetricName = [metric.name stringByReplacingOccurrencesOfString:kPlatformPlaceholder withString:platform];
            }

            [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:deferredMetricName
                                                            value:[NSNumber numberWithLongLong:1]
                                                            scope:@""
                                                  produceUnscoped:YES
                                                  additionalValue:nil]];
        }

        [deferredMetrics removeAllObjects];
    }
}

@end
