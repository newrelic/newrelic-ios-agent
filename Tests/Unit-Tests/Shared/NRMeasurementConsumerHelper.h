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
@property(nonatomic,strong) id result;
@property(nonatomic,strong) NSMutableArray<id>* consumedMeasurements;
@end
