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
    NSString *payloadType = @"mobile";
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"2" traceID:@"4" parentID:@"5" trustedAccountKey:@"6"];
    
    // Then
    NSDictionary *event = [payload JSONObject];
    XCTAssertEqualObjects(event[@"v"], @"[0,2]");
    
    NSDictionary *data = event[@"d"];
    XCTAssertEqual([data[@"ti"] doubleValue], timestamp);
    XCTAssertEqualObjects(data[@"ty"], payloadType);
    XCTAssertEqual(data[@"ac"], @"1");
    XCTAssertEqual(data[@"ap"], @"2");
    XCTAssertNotNil(data[@"id"]);
    XCTAssertEqual(data[@"tr"], @"4");
    XCTAssertEqual(data[@"tk"], @"6");

}


@end
