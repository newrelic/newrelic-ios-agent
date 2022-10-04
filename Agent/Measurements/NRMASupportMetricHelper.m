//
//  NRMASupportMetricHelper.m
//  Agent
//
//  Created by Chris Dillard on 7/12/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import "NRMASupportMetricHelper.h"
#import "NewRelicInternalUtils.h"
#import "NRMAMeasurements.h"
#import "NRMATaskQueue.h"
#import "NRMAFlags.h"

@implementation NRMASupportMetricHelper

//
// The value _additionalValue being non-nil means that this is a Data Usage Supportability Metric.
//

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

+ (void) processDeferredMetrics {
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

@end
