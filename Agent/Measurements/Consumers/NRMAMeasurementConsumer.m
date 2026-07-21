//
//  NRMAMeasurementConsumer.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/20/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementConsumer.h"

@implementation NRMAMeasurementConsumer
- (id) initWithType:(NRMAMeasurementType)type
{
    self = [super init];
    if (self) {
        _measurementType = type;
    }
    return self;
}

- (NRMAMeasurementType) measurementType
{
    return _measurementType;
}

- (void) consumeMeasurement:(NRMAMeasurement *)measurement
{
}

- (void) consumeMeasurements:(NSDictionary*)measurements
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-selector-match"
    if (![measurements isKindOfClass:[NSDictionary class]]) {
        return;
    }
    for (NSNumber* key in [measurements allKeys]){
        id value = [measurements objectForKey:key];
        if (![value respondsToSelector:@selector(allObjects)]) {
            continue;
        }
        // Defense-in-depth: snapshot inside a guard. Callers now hand us detached sets
        // (see NRMAMeasurementProducer/NRMAMeasurementPool), but if a set is ever mutated
        // mid-enumeration we skip it instead of crashing on a freed element.
        NSArray* snapshot = nil;
        @try {
            snapshot = [value allObjects];
        } @catch (NSException* exception) {
            continue;
        }
        for (NRMAMeasurement* measurement in snapshot) {
            [self consumeMeasurement:measurement];
        }
    }
#pragma clang diagnostic pop
}
@end
