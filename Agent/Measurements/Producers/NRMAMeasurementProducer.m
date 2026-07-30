//
//  NRMAMeasurementProducer.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/20/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementProducer.h"
#import "NRMAMeasurementException.h"
@implementation NRMAMeasurementProducer

- (void) dealloc
{
    self.producedMeasurements = nil;
}

- (id) initWithType:(NRMAMeasurementType)type
{

    self = [super init];
    if (self) {
        self.producedMeasurements = [[NSMutableDictionary alloc] init];
        _measurementType = type;
    }
    return self;
}

- (NRMAMeasurementType) measurementType
{
    return _measurementType;
}

- (void) setMeasurementType:(NRMAMeasurementType)type {
    _measurementType = type;
}
- (void) produceMeasurement:(NRMAMeasurement *)measurement
{
    @synchronized(self.producedMeasurements) {
        NSNumber* key = [NSNumber numberWithInt:measurement.type];
        NSMutableSet* typeSet = [self.producedMeasurements objectForKey:key];
        if (!typeSet) {
            typeSet = [NSMutableSet set];
            [self.producedMeasurements setObject:typeSet forKey:key];
        }
        [typeSet addObject:measurement];
    }
}

// This method expects a dictionary of sets.
- (void) produceMeasurements:(NSDictionary*)measurements {
    if (![measurements isKindOfClass:[NSDictionary class]]) {
        return;
    }
    @synchronized(self.producedMeasurements) {
        for (NSNumber* key in measurements.allKeys) {
            id value = [measurements objectForKey:key];
            if (![value isKindOfClass:[NSSet class]]) {
                continue;
            }
            NSMutableSet* existing = [self.producedMeasurements objectForKey:key];
            if (existing) {
                [existing unionSet:value];
            } else {
                // Store a private mutable copy so this producer exclusively owns the set.
                // Never alias a set instance that another thread may still mutate — that
                // shared-mutable-set race is what crashes consumers enumerating the set.
                [self.producedMeasurements setObject:[value mutableCopy] forKey:key];
            }
        }
    }
}
- (NSDictionary*) drainMeasurements
{

    @synchronized(self.producedMeasurements) {
        // Hand consumers a fully detached snapshot: copy each set so nothing a consumer
        // iterates can be mutated by later production on another thread. A shallow
        // initWithDictionary: would share the same NSMutableSet instances (use-after-free risk).
        NSMutableDictionary* measurements = [[NSMutableDictionary alloc] initWithCapacity:self.producedMeasurements.count];
        for (NSNumber* key in self.producedMeasurements.allKeys) {
            id value = [self.producedMeasurements objectForKey:key];
            if ([value isKindOfClass:[NSSet class]]) {
                [measurements setObject:[value copy] forKey:key];
            }
        }
        [self.producedMeasurements removeAllObjects];
        return measurements;
    }
}

@end
