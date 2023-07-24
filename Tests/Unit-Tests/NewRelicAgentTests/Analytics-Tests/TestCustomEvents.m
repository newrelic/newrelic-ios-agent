//
//  TestCustomEvents.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMACustomEvent.h"

@interface TestCustomEvents : XCTestCase

@end

@implementation TestCustomEvents

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCustomEventCreation {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
}

- (void)testGetEventAge {
    // Given
    NSDate *currentTimeStamp = [NSDate now];
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:@"Time Event"
                                                            timestamp:100
                                          sessionElapsedTimeInSeconds:1000];
    
    // Then
    XCTAssertGreaterThan([sut getEventAge], 0);
    XCTAssertLessThanOrEqual([sut getEventAge], [currentTimeStamp timeIntervalSince1970]);
}


@end
