//
//  NRMAMetricSet.h
//  NewRelicAgent
//
//  Created by Jonathan Karon on 5/23/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestable.h"
#import "NRMAHarvestAware.h"

@interface NRMAMetricSet : NRMAHarvestable <NRMAHarvestAware>

- (void)addValue:(NSNumber *)value forMetric:(NSString *)metricName;

- (void) addValue:(NSNumber *)value
        forMetric:(NSString *)metricName
        withScope:(NSString*)scope
  additionalValue:(NSNumber *)additionalValue;

- (void)reset;

- (void) addMetrics:(NRMAMetricSet*)metricSet;

- (void) addExclusiveTime:(NSNumber*)exclusiveTime
                forMetric:(NSString*)metricName
                withScope:(NSString*)scope;

- (id) JSONObject;

// This will remove the oldest unique metics until the number of metrics are equal to count.
- (void) trimToSize:(NSUInteger) count;

/*
 * Will iterate through stored metrics and removed the recorded
 * values older than age. if there are no values left the metric
 * itself will also be removed.
 */
- (void) removeMetricsWithAge:(NSTimeInterval)age;

// Returns the number of unique metrics stored in NRMAMetricSet.
- (NSUInteger) count;

- (NSDictionary*) flushMetrics;

@end
