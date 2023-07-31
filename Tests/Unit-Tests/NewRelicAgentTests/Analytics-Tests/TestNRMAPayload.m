//
//  TestNRMAPayload.m
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMAPayload.h"
#import "BlockAttributeValidator.h"

@interface TestNRMAPayload : XCTestCase

@end

@implementation TestNRMAPayload {
    
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    }

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPayloadCreation {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
    NSString *eventType = @"New Event";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithEventType:eventType timestamp:timestamp accountID:@"1" appID:@"1" ID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];
    
    // Then
    NSDictionary *event = [payload JSONObject];
    XCTAssertEqual([event[@"timestamp"] doubleValue], timestamp);
    XCTAssertEqual([event[@"timeSinceLoad"] unsignedLongLongValue], elapsedTime);

    XCTAssertEqual(event[@"eventType"], eventType);
}



@end
