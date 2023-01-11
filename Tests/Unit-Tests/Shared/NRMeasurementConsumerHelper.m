//
//  NRMAMeasurementCosumerHelper.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/23/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMeasurementConsumerHelper.h"
#import "NRLogger.h"

@implementation NRMAMeasurementConsumerHelper

- (id) initWithType:(NRMAMeasurementType)type {
    self = [super initWithType:type];
    
    if(self) {
        self.consumedMeasurements = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) consumeMeasurement:(NRMAMeasurement *)measurement {
    NRLOG_VERBOSE(@"Measurement: %@",measurement);
    self.result = measurement;
    [self.consumedMeasurements addObject:measurement];
}
@end
