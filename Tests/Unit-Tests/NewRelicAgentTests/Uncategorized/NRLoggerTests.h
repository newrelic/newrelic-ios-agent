//
//  NRLoggerTests.h
//  NewRelicAgent
//
//  Created by Chris Dillard on 2/15/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMeasurementConsumerHelper.h"


@interface NRLoggerTests : XCTestCase
{
    NRMAMeasurementConsumerHelper* helper; 
    NSString* category;
    NSString* name;
}
@end
