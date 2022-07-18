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

@end
