//
//  TestRequestEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMARequestEvent.h"
#import "NRMAPayload.h"
#import "BlockAttributeValidator.h"

@interface TestRequestEvents : XCTestCase

@end

@implementation TestRequestEvents {
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

- (void)testRequestEventCreation {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];
    
    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp sessionElapsedTimeInSeconds:elapsedTime payload:payload withAttributeValidator:agreeableAttributeValidator];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    
    NSDictionary* dict = event[@"payload"];
    NSDictionary* dict2 = [payload JSONObject];
    XCTAssertEqualObjects(dict, dict2);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
}

- (void)testGetEventAge {
    // Given
    NSDate *currentTimeStamp = [NSDate now];
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:100 accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:100
                                          sessionElapsedTimeInSeconds:1000
                                                                payload:payload withAttributeValidator:agreeableAttributeValidator];
    
    // Then
    XCTAssertGreaterThan([sut getEventAge], 0);
    XCTAssertLessThanOrEqual([sut getEventAge], [currentTimeStamp timeIntervalSince1970]);
}

- (void)testAddStringAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    
    NSString *attributeName = @"String Attribute";
    NSString *stringAttributeValue = @"Go Pack Go";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                                                payload:payload
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
}

- (void)testAddBoolAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    NSString *attributeName = @"Bool Attribute";
    
    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                                                payload:payload
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:NO];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
    XCTAssertFalse(event[attributeName]);
}

- (void)testUnsignedLongLongAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    NSString *attributeName = @"Unsigned Long Long Attribute";
    
    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                                                payload:payload
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:@(UINT_MAX)];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
    XCTAssertEqual([event[attributeName] unsignedLongLongValue], UINT_MAX);
}

- (void)testDoubleAttribute {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    NSString *attributeName = @"Double Attribute";
    double pi = M_PI;
    
    // When
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                            sessionElapsedTimeInSeconds:elapsedTime
                                                                payload:payload
                                               withAttributeValidator:agreeableAttributeValidator];
    [sut addAttribute:attributeName value:@(pi)];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
    XCTAssertEqual([event[attributeName] doubleValue], pi);
}

- (void)testInvalidAttributeNamePreventsAdding {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

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
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                                      payload:payload
                                               withAttributeValidator:badNameValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
//    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
    XCTAssertNil(event[attributeName]);
}

- (void)testInvalidAttributeValuePreventsAdding {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"MobileRequest";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

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
    NRMARequestEvent *sut = [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                                          sessionElapsedTimeInSeconds:elapsedTime
                                                                payload:payload
                                               withAttributeValidator:badNameValidator];
    [sut addAttribute:attributeName value:stringAttributeValue];
    
    // Then
    NSDictionary *event = [sut JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);
    XCTAssertEqualObjects(event[@"eventType"], eventType);
//    XCTAssertTrue([event[attributeName] isEqualToString:stringAttributeValue]);
    XCTAssertNil(event[attributeName]);
}


@end
