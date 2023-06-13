//
//  TestIntegratedEventManager.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMAEventManager.h"

#import "NRMAAnalyticEvent.h"


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

- (void)testAddEvent {
    // Given
    NRMAAnalyticEvent *testEvent = [NRMAAnalyticEvent new];
    
    // When
    BOOL result = [sut addEvent:testEvent];
    
    // Then
    XCTAssertTrue(result,"Adding the event was not successful");
}

- (void)testRetrieveEventJSON {
    // Given
    NRMAAnalyticEvent *testEvent = [NRMAAnalyticEvent new];
    NSError *error = nil;
    
    // When
    [sut addEvent:testEvent];
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error];
    
    // Then
    XCTAssertNotNil(eventJSONString, "Event JSON String not properly created");
    
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertNotNil(decode[0][@"timestamp"]);
    XCTAssertNotNil(decode[0][@"timeSinceLoad"]);
}

@end
