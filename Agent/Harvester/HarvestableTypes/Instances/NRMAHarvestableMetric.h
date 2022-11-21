//
//  NRMAMetric.h
//  NewRelicAgent
//
//  Created by Jonathan Karon on 5/23/13.
//  Copyright (c) 2014 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestable.h"

#define kEndDateKey   @"endDate"
#define kValueKey     @"value"
#define kExclusiveKey @"exclusive"
#define kCountKey     @"count"
#define kTotalKey     @"total"
#define kMinKey       @"min"
#define kMaxKey       @"max"
#define kSumOfSqKey   @"sum_of_squares"

@interface NRMAHarvestableMetric : NRMAHarvestable
{
    long long lastUpdateMillis;
}
@property (nonatomic, strong) NSString *metricName;
@property(strong,nonatomic) NSNumber* additionalValue;

- (NSArray*) allValues;

- (id)initWithMetricName:(NSString *)name
                   scope:(NSString*)scope;

- (id) initWithMetricName:(NSString*) name;

// Helper method, just calls addValue with a parameter of 1;
 - (void) incrementCount;

// Returns the count of metric values contained
- (NSUInteger) count;

// Inserts a new value into metric as well as captures an endDate and threadID for the value.
- (void) addValue:(NSNumber *)value;

// Call this with non-null number for Data Use Supportability Metrics
- (void) addAdditionalValue:(NSNumber *)additionalValue;

//Remove all stored values
- (void) reset;

// Removes all stored values older than age
- (void) removeValuesWithAge:(NSTimeInterval)age;

// This will return the endDate of the most recently added value
- (long long) lastUpdatedMillis;

/*
 * Calculates metric data points (min, max, avg, sos, etc)
 * and returns a JSON transformable dictionary for transmitting
 * to the collector.
 */
- (id) JSONObject;

@end
