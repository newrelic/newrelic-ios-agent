//
//  NRMAHarvesterConnectionTests.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/28/13.
//  Copyright (c) 2013 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAHarvesterConnection.h"
#import "NRAgentTestBase.h"
#import "NRMeasurementConsumerHelper.h"

@interface NRMAHarvesterConnectionTests : NRMAAgentTestBase
{
    NRMAHarvesterConnection* connection;

    NRMAMeasurementConsumerHelper* helper;

    
}
@end
