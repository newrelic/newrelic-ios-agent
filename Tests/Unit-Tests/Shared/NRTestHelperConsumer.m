
//
//  NRMATestHelperConsumer.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/30/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRTestHelperConsumer.h"


@implementation NRMATestHelperConsumer
- (void) consumeMeasurements:(NSDictionary *)measurements {
    @synchronized (self.consumedmeasurements)
    {
        self.consumedmeasurements = measurements;
    }
}
@end
