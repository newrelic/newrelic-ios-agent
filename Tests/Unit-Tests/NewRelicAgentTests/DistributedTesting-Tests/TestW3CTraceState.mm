//
//  TestW3CTraceState.m
//  Agent_Tests
//
//  Created on 1/7/21.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <Connectivity/Facade.hpp>
#import "W3CTraceState.h"

@interface TestW3CTraceState : XCTestCase

@end

@implementation TestW3CTraceState

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testHeaderString {
    // arrange
    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    std::string accountStr("10816994");
    std::string appIdStd("25789457");
    std::string spanId("17172750e6ff8549");
    long long timestamp = 1609970157093;
    
    // act
    payload->setAccountId(accountStr);
    payload->setAppId(appIdStd);
    payload->setId(spanId);
    payload->setTimestamp(timestamp);

    std::string trustedAccountStd("1");
    payload->setTrustedAccountKey(trustedAccountStd);
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload: payload];
    
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *desiredHeader = @"1@nr=0-2-10816994-25789457-17172750e6ff8549---1609970157093";
    
    // assert
    XCTAssert([traceState isEqualToString: desiredHeader]);
}

- (void)testHeaderStringNRMAPayload {
    NSString* accountStr = @"10816994";
    NSString* appIdStd = @"25789457";
    NSString* spanId = @"17172750e6ff8549";
    NSString* traceId = @"edd7db371b2faa5b";
    long long timestamp = 1609970157093;
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:accountStr appID:appIdStd traceID:traceId parentID:spanId trustedAccountKey:@"1"];
    payload.id = spanId;
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithNRMAPayload: payload];
    
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *desiredHeader = @"1@nr=0-2-10816994-25789457-17172750e6ff8549---1609970157093";
    
    // assert
    XCTAssert([traceState isEqualToString: desiredHeader]);
}

- (void)testHeaderStringNoTrustedAccount {
    // arrange
    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    std::string accountStr("10816994");
    std::string appIdStd("25789457");
    std::string spanId("17172750e6ff8549");
    long long timestamp = 1609970157093;

    // act
    payload->setAccountId(accountStr);
    payload->setAppId(appIdStd);
    payload->setId(spanId);
    payload->setTimestamp(timestamp);
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload: payload];
    
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *desiredHeader = @"@nr=0-2-10816994-25789457-17172750e6ff8549---1609970157093";

    // assert
    XCTAssert([traceState isEqualToString: desiredHeader]);
}

- (void)testHeaderStringNoTrustedAccountNRMAPayload {
    NSString* accountStr = @"10816994";
    NSString* appIdStd = @"25789457";
    NSString* spanId = @"17172750e6ff8549";
    long long timestamp = 1609970157093;
    NRMAPayload* payload = [[NRMAPayload alloc] init];
    payload.accountId = accountStr;
    payload.appId = appIdStd;
    payload.id = spanId;
    payload.timestamp = timestamp;
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithNRMAPayload: payload];
    
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *desiredHeader = @"@nr=0-2-10816994-25789457-17172750e6ff8549---1609970157093";

    // assert
    XCTAssert([traceState isEqualToString: desiredHeader]);
}

@end
