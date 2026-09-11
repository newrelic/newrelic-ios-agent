//
//  NRMAMeasurementCosumerHelper.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/23/13.
//  Copyright © 2023 New Relic. All rights reserved.
//
#import "NRMAMeasurementConsumer.h"
#import "NRMeasurementConsumerHelper.h"

@interface NRMAMeasurementConsumerHelper : NRMAMeasurementConsumer
// `result` is written from the background NRMATaskQueue dispatch queue (via
// consumeMeasurement:) while tests busy-wait on it from the test thread. It must
// be atomic so the concurrent read/write doesn't over-release and crash (EXC_BAD_ACCESS).
@property(atomic,strong) id result;
@property(atomic,strong) NSMutableArray<id>* consumedMeasurements;
@end
