//
//  TestIntegratedEventManager.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMAEventManager.h"

#import "NRMACustomEvent.h"


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

- (void)testRetrieveEventJSON {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
//    NRMAAnalyticEvent *testEvent = [[NRMAAnalyticEvent alloc] initWithTimestamp:timestamp
    NRMACustomEvent *testEvent = [[NRMACustomEvent alloc] initWithEventType:@"CustomEvent"
                                                                  timestamp:timestamp
                                                sessionElapsedTimeInSeconds:elapsedTime];
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
    double retrievedTimestamp = [decode[0][@"timestamp"] doubleValue];
    XCTAssertEqual(retrievedTimestamp, timestamp);
    XCTAssertNotNil(decode[0][@"timeSinceLoad"]);
    unsigned long long retrievedElapsedTime = [decode[0][@"timeSinceLoad"] unsignedLongLongValue];
    XCTAssertEqual(retrievedElapsedTime, elapsedTime);
}

- (void)testMaxBufferSize {
    // Given
//    [sut setMaxEventBufferSize:1];
    
    // When
    
    
    // Then
}

@end
