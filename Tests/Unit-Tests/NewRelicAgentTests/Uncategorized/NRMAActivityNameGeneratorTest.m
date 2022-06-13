//
//  NRMAActiveNameGeneratorTest.m
//  Agent_Tests
//
//  Created by Anna Huller on 6/13/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAActivityNameGenerator.h"
#import "NRMAMethodProfiler.h"

@interface NRMAActivityNameGeneratorTest : XCTestCase

@end

@implementation NRMAActivityNameGeneratorTest

-(void) testGenerateName {
   XCTAssertNoThrow([NRMAActivityNameGenerator generateActivityNameFromClass:[NRMAMethodProfiler class] selector:@selector(sendData:)], @"Normal use case should not error");
    XCTAssertNotNil([NRMAActivityNameGenerator generateActivityNameFromClass:[NRMAMethodProfiler class] selector:@selector(sendData:)], @"should return value when class is valid");
    XCTAssertNoThrow([NRMAActivityNameGenerator generateActivityNameFromClass:nil selector:nil], @"Should not throw with nil inputs");
    XCTAssertNil([NRMAActivityNameGenerator generateActivityNameFromClass:nil selector:@selector(sendData:)], @"should return nil name when class is empty");
}

@end
