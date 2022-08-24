//
//  NRMAMetric.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 5/23/13.
//  Copyright (c) 2013 New Relic. All rights reserved.
//

#import <objc/runtime.h>

#import "NRMAHarvestableMetric.h"
#import "NewRelicInternalUtils.h"


@interface NRMAHarvestableMetric()

@property(nonatomic, strong) NSMutableArray* collectedValues;
@property(strong,nonatomic) NSString* scope;

@end

@implementation NRMAHarvestableMetric

- (id) initWithMetricName:(NSString*) name
{
    return [self initWithMetricName:name scope:@""];
}
- (id)initWithMetricName:(NSString *)name
                   scope:(NSString*)scope
{
    self = [super initWithType:NRMA_HARVESTABLE_OBJECT];
    if (self) {
        self.scope = scope?:@"";
        self.metricName = name;
        self.collectedValues = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray*) allValues
{
    return [self.collectedValues copy];
}


- (NSUInteger) count {
    return [self.collectedValues count];
}

- (long long) lastUpdatedMillis
{
    if (!self.collectedValues.count) return 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-selector-match"
    return [self.collectedValues[self.collectedValues.count-1][kEndDateKey] longLongValue];
#pragma clang diagnostic pop
}

- (void)addValue:(NSNumber *)value
{
    [self.collectedValues addObject:@{kValueKey:value,
                                      kEndDateKey:@(NRMAMillisecondTimestamp())}];
}

- (void)addAdditionalValue:(NSNumber *)additionalValue {
    self.additionalValue = additionalValue;
}

- (void) incrementCount
{
    [self addValue:@1];
}

- (void)reset
{
    [self.collectedValues removeAllObjects];
}

- (id)JSONObject
{
    NSUInteger count = self.collectedValues.count;
    double_t total = 0;
    double_t min = 0;
    double_t max = 0;
    double_t sum_of_squares = 0;

    NSDictionary* nameScopeDictionary = @{@"name":self.metricName,@"scope":self.scope};

    /*
     The value _additionalValue being non-nil means that this is a Data Use Supportability Metric.
     -NRMAHarvestableMetric is being reused for a new type of support metric.
     Data format for these metrics should be:
     [Interaction Count, Uncompressed Bytes Sent, Bytes Received, 0, 0, 0]

     where this Metric Time Slice Data was previously used for data of form
     [Count, Total Time, Exclusive Time, Min, Max, Sum of Sq]
     */
    if (_additionalValue != nil) {
        if (_collectedValues.count > 0) {
            for (NSDictionary *dictionary in self.collectedValues) {

                NSNumber* value = dictionary[kValueKey];

                total += [value doubleValue];
            }
        }

        double_t exclusive = [_additionalValue doubleValue];

        NSDictionary* value = @{
            kCountKey    : @(count),
            kTotalKey    : @(total),
            kMinKey      : @(min),
            kMaxKey      : @(max),
            kSumOfSqKey  : @(sum_of_squares),
            kExclusiveKey: @(exclusive)
        };
        return [@[nameScopeDictionary,value] mutableCopy];
    }

    if (count > 0) {
        BOOL set = NO;
        for (NSDictionary *dictionary in self.collectedValues) {
            NSNumber* value = dictionary[kValueKey];
            double_t val = [value doubleValue];
            if (! set) {
                min = max = val;
                set = YES;
            }
            total += val;
            min = MIN(min, val);
            max = MAX(max, val);
        }

        double_t avg = total / count;
        for (NSDictionary *dictionary in self.collectedValues) {
            NSNumber* value = dictionary[kValueKey];
            double_t val = [value doubleValue];
            double_t diff = avg - val;
            sum_of_squares += diff * diff;
        }
    }
    NSDictionary* value = @{
        kCountKey   : @(count),
        kTotalKey   : @(total),
        kMinKey     : @(min),
        kMaxKey     : @(max),
        kSumOfSqKey : @(sum_of_squares)
    };

    return [@[nameScopeDictionary,value] mutableCopy];
}

- (void) removeValuesWithAge:(NSTimeInterval)age
{
    //the metrics are sorted by date by default
    NSArray* immutableIterator = [self.collectedValues copy];
    for (NSDictionary* metricValue in immutableIterator) {
        NSDate* metricEndDate = metricValue[kEndDateKey];
        if ([metricEndDate isKindOfClass:[NSDate class]]) { //safety first!
            //darn right
            if ([[NSDate date] timeIntervalSinceDate:metricEndDate] >= age) {
                [self.collectedValues removeObject:metricValue];
            } else {
                /*
                 if we find a date that is not older than our age param
                 we will not find an older one later in the list.
                 so we are done.
                 */
                return;
            }
        } else {
            //wtf is going on, go away bad object.
            [self.collectedValues removeObject:metricValue];
        }
    }
}


@end
