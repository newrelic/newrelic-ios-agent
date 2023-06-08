//
//  TestIntegratedEventManager.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMAEventManager.h"

@interface TestIntegratedEventManager : XCTestCase
@end

@implementation TestIntegratedEventManager
    NRMAEventManager *sut;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    sut = [NRMAEventManager new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

//- (void)testExample {
//    // This is an example of a functional test case.
//    // Use XCTAssert and related functions to verify your tests produce the correct results.
//}
//
//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
