//
//  TestW3CTraceParent.m
//  Agent_Tests
//
//  Created on 1/7/21.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <Connectivity/Facade.hpp>
#import "W3CTraceParent.h"
#import "NRMAHTTPUtilities.h"

@interface TestW3CTraceParent : XCTestCase

@end

@implementation TestW3CTraceParent

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
    std::string traceId("edd7db371b2faa5b");
    long long timestamp = 1609970157093;
    
    // act
    payload->setAccountId(accountStr);
    payload->setAppId(appIdStd);

    std::string trustedAccountStd("1");

    payload->setTrustedAccountKey(trustedAccountStd);

    payload->setId(spanId);
    payload->setTraceId(traceId);
    payload->setTimestamp(timestamp);
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload: payload];
    
    [traceContext setTrustedAccount:NRTraceContext];
    
    NSString *traceParent = [W3CTraceParent headerFromContext:traceContext];
    NSString *desiredHeader = @"00-edd7db371b2faa5b-17172750e6ff8549-00";
    
    // assert
    XCTAssert([traceParent isEqualToString: desiredHeader]);
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
    
    [traceContext setTrustedAccount:NRTraceContext];
    
    NSString *traceParent = [W3CTraceParent headerFromContext:traceContext];
    NSString *desiredHeader = @"00-edd7db371b2faa5b-17172750e6ff8549-00";
    
    // assert
    XCTAssert([traceParent isEqualToString: desiredHeader]);
}

@end
