//
//  NRMAMeasurementPool.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/20/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementConsumer.h"
#import "NRMAProducerProtocol.h"
#import "NRMAMeasurementProducer.h"
@interface NRMAMeasurementPool : NRMAMeasurementProducer <NRMAConsumerProtocol> {
}
@property(strong) NSString* identifier;
@property(strong) NSMutableDictionary* producers;
@property(strong) NSMutableDictionary* consumers;
- (void) addMeasurementProducer:(id<NRMAProducerProtocol>)producer;
- (void) removeMeasurementProducer:(id<NRMAProducerProtocol>)producer;
- (void) addMeasurementConsumer:(id<NRMAConsumerProtocol>)consumer;
- (void) removeMeasurementConsumer:(id<NRMAConsumerProtocol>)consumer;
- (void) broadcastMeasurements;
// Call before releasing. this is irreversible.
- (void) shutdown;

@end
