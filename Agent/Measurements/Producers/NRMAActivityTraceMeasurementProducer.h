//
//  NRMAActivityTraceMeasurementProducer.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/11/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementProducer.h"
#import "NRMAActivityTrace.h"
@interface NRMAActivityTraceMeasurementProducer : NRMAMeasurementProducer
- (void) produceMeasurementWithTrace:(NRMAActivityTrace*)trace;
@end
