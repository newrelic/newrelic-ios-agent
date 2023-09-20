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
#import "BlockAttributeValidator.h"


@interface TestIntegratedEventManager : XCTestCase {
    NRMAEventManager *sut;
    BlockAttributeValidator *agreeableAttributeValidator;
}
@end

@implementation TestIntegratedEventManager

    static NSString *testFilename = @"fbstest_tempStore";

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    sut = [[NRMAEventManager alloc] initWithPersistentStore:[[PersistentEventStore alloc] initWithFilename:testFilename
                                                                                           andMinimumDelay:1]];
    
    if(agreeableAttributeValidator == nil) {
        agreeableAttributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
            return YES;
        } valueValidator:^BOOL(id value) {
            return YES;
        } andEventTypeValidator:^BOOL(NSString *eventType) {
            return YES;
        }];
    }
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
                                                sessionElapsedTimeInSeconds:elapsedTime
                                                     withAttributeValidator:agreeableAttributeValidator];
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
    [sut setMaxEventBufferSize:1];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEevntTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:5
                                                     sessionElapsedTimeInSeconds:15
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    // When
    [sut addEvent:customEventOne];
    [sut addEvent:customEevntTwo];
    
    // Then
    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(decode.count, 1);
}

- (void)testZeroMaxBufferSize {
    [sut setMaxEventBufferSize:0];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    [sut addEvent:customEventOne];
    
    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(decode.count, 0);
}

- (void)testNotAgedOutEvents {
    // Given
    [sut setMaxEventBufferTimeInSeconds:NSUIntegerMax];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    // When
    [sut addEvent:customEventOne];
    
    // Then
    XCTAssertFalse([sut didReachMaxQueueTime:[[NSDate now] timeIntervalSince1970]]);
}

- (void)testAgedOutEvents {
    // Given
    [sut setMaxEventBufferTimeInSeconds:1];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    // When
    [sut addEvent:customEventOne];
    
    // Then
    XCTAssertTrue([sut didReachMaxQueueTime:[[NSDate now] timeIntervalSince1970]]);
}

- (void)testEmptyEvents {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];

    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    
    XCTAssertEqual(decode.count, 3);
    
    
    [sut empty];
    
    NSString *emptyJSONString = [sut getEventJSONStringWithError:&error];
    NSArray *emptyDecode = [NSJSONSerialization JSONObjectWithData:[emptyJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(emptyDecode.count, 0);
}

- (void)testEmptyEventsResetOldestEventTime {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    [sut setMaxEventBufferTimeInSeconds:1];
    
    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];
    
    XCTAssertTrue([sut didReachMaxQueueTime:2000]);

    [sut empty];

    XCTAssertFalse([sut didReachMaxQueueTime:2000]);
}

@end
