//
//  NRMAHarvesterStateTest.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRAgentTestBase.h"
@interface TestHarvester : NRMAHarvester
@end
@interface NRMAHarvesterStateTest : NRMAAgentTestBase
{
    TestHarvester* harvest;
}
@end
