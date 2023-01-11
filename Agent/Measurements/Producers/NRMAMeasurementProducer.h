//
//  NRMAMeasurementProducer.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/20/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAProducerProtocol.h"
@interface NRMAMeasurementProducer : NSObject <NRMAProducerProtocol>
{
    NRMAMeasurementType _measurementType;
}

@property(strong,atomic) NSMutableDictionary* producedMeasurements;

@property(setter = setMeasurementType:, getter = measurementType) NRMAMeasurementType type;
- (id) initWithType:(NRMAMeasurementType)type;
- (void) produceMeasurement:(NRMAMeasurement *)measurement;

// This method expects a dictionary of mutable sets.
- (void) produceMeasurements:(NSDictionary*)measurements;
- (NSDictionary*) drainMeasurements;

@end
