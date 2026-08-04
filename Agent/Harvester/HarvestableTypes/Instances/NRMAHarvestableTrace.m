//
//  NRMAHarvestableTrace.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestableTrace.h"
#import "NRMAScopedMeasurement.h"
#import "NRMAScopedHTTPTransactionMeasurement.h"

@implementation NRMAHarvestableTrace
- (id) initWithTrace:(NRMATrace*)trace
{
    self = [super initWithSegmentType:@"trace"];
    if (self) {
        self.name = trace.name;
        self.startTime = (long long)trace.entryTimestamp;
        self.endTime = (long long)trace.exitTimestamp;
        self.threadInfo = trace.threadInfo;
        
        self.subSegments = [[NSMutableArray alloc] init];
        // Snapshot children under the same lock NRMATrace.addChild: uses, so we
        // don't fast-enumerate while another thread mutates the set
        // (NSGenericException: "Collection ... was mutated while being enumerated").
        NSArray* childrenSnapshot = nil;
        @synchronized(trace.children) {
            childrenSnapshot = [trace.children allObjects];
        }
        for (NRMATrace* subTrace in childrenSnapshot) {
            [self.subSegments addObject:[[NRMAHarvestableTrace alloc] initWithTrace:subTrace]];
        }
        self.events = [[NRMAScopedMeasurements alloc]initWithMeasurementType:NRMAMT_NamedEvent];
        self.network = [[NRMAScopedMeasurements alloc] initWithMeasurementType:NRMAMT_Network];

        // Same race exists for scopedMeasurements, mutated under @synchronized in
        // NRMATrace.consumeMeasurement:. Snapshot under lock before iterating.
        NSArray* measurementsSnapshot = nil;
        @synchronized(trace.scopedMeasurements) {
            measurementsSnapshot = [trace.scopedMeasurements copy];
        }
        for ( NRMAMeasurement* measurement in measurementsSnapshot) {
            if (measurement.type == NRMAMT_HTTPTransaction || measurement.type == NRMAMT_Network) {
                NRMAScopedMeasurement* scopedMeasurement = [[NRMAScopedHTTPTransactionMeasurement alloc] initWithMeasurement:measurement];
                scopedMeasurement.threadInfo = self.threadInfo;
                [self.network addScopedMeasurement:scopedMeasurement];
            }
            else if ( measurement.type == NRMAMT_NamedEvent) {
                [self.events addScopedMeasurement:[[NRMAScopedMeasurement alloc] initWithMeasurement:measurement]];
            }
        }
    }
    return self;
}

- (id) JSONObject
{
    NSMutableArray* array  = [super JSONObject];
    // Thread info.
    [array insertObject:@{@"type":@"TRACE"} atIndex:0];
    [array addObject:@[[NSNumber numberWithUnsignedInt:self.threadInfo.identity],[self.threadInfo.name length]?self.threadInfo.name:@""]];
    NSMutableArray* subSegments = [[NSMutableArray alloc] init];
    for (NRMAHarvestable* hObj in self.subSegments) {
        [subSegments addObject:[hObj JSONObject]];
    }
    
    if ([self.network count]) {
        [subSegments addObjectsFromArray:[self.network JSONObject]];
    }
    if ([self.events count]) {
        [subSegments addObjectsFromArray:[self.events JSONObject]];
    }
        
    [array addObject:subSegments];
    return array;
}
@end
