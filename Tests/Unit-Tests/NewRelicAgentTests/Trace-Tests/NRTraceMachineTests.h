//
//  NRMATraceMachineTests.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAMeasurementConsumer.h"
#import "NRMeasurementConsumerHelper.h"
@interface NRMATraceMachineTests : XCTestCase
{
    BOOL trueValue;
    BOOL falseValue;
    NRMAMeasurementConsumerHelper* helper;
    id harvestConfigurationObject;

}
@end
