//
//  TestCustomEvents.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMACustomEvent.h"
#import "BlockAttributeValidator.h"

@interface TestCustomEvents : XCTestCase

@end

@implementation TestCustomEvents {
    BlockAttributeValidator *agreeableAttributeValidator;
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    if(agreeableAttributeValidator == nil) {
        agreeableAttributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *) {
            return YES;
        } valueValidator:^BOOL(id) {
            return YES;
        } andEventTypeValidator:^BOOL(NSString *) {
            return YES;
        }];
    }
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
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:agreeableAttributeValidator];
    
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
                                          sessionElapsedTimeInSeconds:1000
                                               withAttributeValidator:agreeableAttributeValidator];
    
    // Then
    XCTAssertGreaterThan([sut getEventAge], 0);
    XCTAssertLessThanOrEqual([sut getEventAge], [currentTimeStamp timeIntervalSince1970]);
}

- (void)testAddStringAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"String Attribute";
    NSString *stringAttributeValue = @"Go Pack Go";
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
}

- (void)testAddBoolAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"Bool Attribute";
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:NO];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
    XCTAssertFalse(event[attributeName]);
}

- (void)testUnsignedLongLongAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"Unsigned Long Long Attribute";
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:@(UINT_MAX)];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
    XCTAssertEqual([event[attributeName] unsignedLongLongValue], UINT_MAX);
}

- (void)testDoubleAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"Double Attribute";
    double pi = M_PI;
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:@(pi)];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
    XCTAssertEqual([event[attributeName] doubleValue], pi);
}

- (void)testInvalidAttributeNamePreventsAdding {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"String Attribute";
    NSString *stringAttributeValue = @"Go Pack Go";
    
    BlockAttributeValidator *badNameValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *) {
        return NO;
    } valueValidator:^BOOL(id) {
        return YES;
    } andEventTypeValidator:^BOOL(NSString *) {
        return YES;
    }];
    
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:badNameValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
//    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
    XCTAssertNil(event[attributeName]);
}

- (void)testInvalidAttributeValuePreventsAdding {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    
    NSString *attributeName = @"String Attribute";
    NSString *stringAttributeValue = @"Go Pack Go";
    
    BlockAttributeValidator *badNameValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *) {
        return YES;
    } valueValidator:^BOOL(id) {
        return NO;
    } andEventTypeValidator:^BOOL(NSString *) {
        return YES;
    }];
    
    
    // When
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                            timestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                               withAttributeValidator:badNameValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqual(event[@"eventType"], @"New Event");
//    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
    XCTAssertNil(event[attributeName]);
}

@end
