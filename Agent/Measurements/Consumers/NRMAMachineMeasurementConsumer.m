//
//  NRMAMachineMeasurementConsumer.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/30/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMachineMeasurementConsumer.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMetricSet.h"
#import "NRMAHarvestableMetric.h"
#import "NRMAHarvestController.h"

@implementation NRMAMachineMeasurementConsumer
- (instancetype) init
{
    self = [super initWithType:NRMAMT_NamedValue];
    if (self) {
    }
    return self;
}

- (void) consumeMeasurement:(NRMAMeasurement *)measurement
{
    if ([measurement isKindOfClass:[NRMANamedValueMeasurement class]]) {
        [NRMAHarvestController addNamedValue:(NRMANamedValueMeasurement*)measurement];
    }
}

- (void) consumeMeasurements:(NSDictionary *)measurements
{
    if (![measurements isKindOfClass:[NSDictionary class]]) {
        return;
    }
    id measurementSet = [measurements objectForKey:[NSNumber numberWithInt:self.measurementType]];
    if (![measurementSet respondsToSelector:@selector(allObjects)]) {
        return;
    }
    // Defense-in-depth: snapshot inside a guard so a set mutated mid-enumeration on
    // another thread is skipped rather than crashing on a freed element.
    NSArray* snapshot = nil;
    @try {
        snapshot = [measurementSet allObjects];
    } @catch (NSException* exception) {
        return;
    }
    for (NRMANamedValueMeasurement* measurement in snapshot) {
        [self consumeMeasurement:measurement];
    }
}
@end
