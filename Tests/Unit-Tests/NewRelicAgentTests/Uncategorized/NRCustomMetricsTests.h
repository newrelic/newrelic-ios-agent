//
//  NRCustomMetricsTests.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 7/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMeasurementConsumerHelper.h"


@interface NRCustomMetricsTests : XCTestCase
{
    NRMAMeasurementConsumerHelper* helper; 
    NSString* category;
    NSString* name;
}
@end
