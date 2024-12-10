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

// The value _additionalValue being non-nil means that this is a Data Usage Supportability Metric.
+ (void) enqueueDataUseMetric:(NSString*)subDestination size:(long)size received:(long)received {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRMABytesOutSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, subDestination]
                                                        value:[NSNumber numberWithLongLong:size]
                                                        scope:@""
                                              produceUnscoped:YES
                                              additionalValue:[NSNumber numberWithLongLong:received]]];
    }
}

+ (void) enqueueFeatureFlagMetric:(BOOL)enabled features:(NRMAFeatureFlags)features {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        for (NSString *name in [NRMAFlags namesForFlags:features]) {
            NSString* featureFlagString = [NSString stringWithFormat:@"Supportability/Mobile/%@/%@/API/%@/%@",
                                           nativePlatform, kPlatformPlaceholder, enabled ? @"enableFeature" : @"disableFeature", name];
            if (deferredMetrics == nil) {
                deferredMetrics = [NSMutableArray array];
            }
            [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:featureFlagString
                                                                  value:[NSNumber numberWithLongLong:1]
                                                                  scope:@""
                                                        produceUnscoped:YES
                                                        additionalValue:nil]];
        }
    }
}

+ (void) enqueueInstallMetric {
    @synchronized(self) {
        if (deferredMetrics == nil) {
            deferredMetrics = [NSMutableArray array];
        }
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:kNRMAAppInstallMetric
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueMaxPayloadSizeLimitMetric:(NSString*)endpoint {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, endpoint]
                                                        value:@1
                                                        scope:nil]];
    }
}

+ (void) enqueueOfflinePayloadMetric:(long)size {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMAOfflineSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest]
                                                        value:[NSNumber numberWithLongLong:size]
                                                        scope:nil]];
    }
}

+ (void) enqueueUpgradeMetric {
    @synchronized(self) {
        if (deferredMetrics == nil) {
            deferredMetrics = [NSMutableArray array];
        }
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:kNRMAAppUpgradeMetric
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueStopAgentMetric {
    @synchronized(self) {
        if (deferredMetrics == nil) {
            deferredMetrics = [NSMutableArray array];
        }
        NSString* metricString = [NSString stringWithFormat:kNRMAStopAgentMetricFormatString, [NewRelicInternalUtils osName], kPlatformPlaceholder];
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:metricString
                                                              value:@1
                                                              scope:nil]];
    }
}

+ (void) enqueueConfigurationUpdateMetric {

    @synchronized(self) {

        if (deferredMetrics == nil) {
            deferredMetrics = [NSMutableArray array];
        }
        NSString* metricString = [NSString stringWithFormat:kNRMAConfigurationUpdated, [NewRelicInternalUtils osName], kPlatformPlaceholder];
        [deferredMetrics addObject:[[NRMAMetric alloc] initWithName:metricString
                                                              value:@1
                                                              scope:nil]];

    }
}

// Logging

+ (void) enqueueLogSuccessMetric:(long)size {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRMALoggingMetricSuccessfulSize, nativePlatform, platform]
                                                        value:[NSNumber numberWithLongLong:size]
                                                        scope:@""
                                              produceUnscoped:YES
                                              additionalValue:nil]];
    }
}

+ (void) enqueueLogFailedMetric {
    @synchronized(self) {
        NSString* nativePlatform = [NewRelicInternalUtils osName];
        NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat: kNRMALoggingMetricFailedUpload, nativePlatform, platform]
                                                        value:@1
                                                        scope:nil]];
    }

}

// End Logging

+ (void) processDeferredMetrics {
    @synchronized(self) {

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
        if (deferredMetrics == nil) { return; }

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
        deferredMetrics = nil;
    }
}

@end
