//
//  NRMAHTTPErrorTraceGenerator.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/10/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementTransmitter.h"
#import "NRMAActivityTrace.h"

@implementation NRMAMeasurementTransmitter
- (id) initWithType:(NRMAMeasurementType)type
    destinationPool:(NRMAMeasurementPool*)pool
{
    self = [super initWithType:type];
    if (self) {
        self.destinationPool = pool;
    }
    return self;
}

@end
