//
//  NRMASupportMetricHelper.h
//  Agent
//
//  Created by Chris Dillard on 7/12/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewRelicFeatureFlags.h"

static NSMutableArray *deferredMetrics = NULL;

@interface NRMASupportMetricHelper : NSObject
+ (void) enqueueDataUseMetric:(NSString*)subDestination size:(long)size received:(long)received;
+ (void) enqueueFeatureFlagMetric:(BOOL)enabled features:(NRMAFeatureFlags)features;
+ (void) enqueueInstallMetric;
+ (void) enqueueMaxPayloadSizeLimitMetric:(NSString*)endpoint;
+ (void) enqueueUpgradeMetric;
+ (void) processDeferredMetrics;
@end
