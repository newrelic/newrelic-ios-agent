//
//  TestNRMATraceContext.mm
//  Agent_Tests
//
//  Created on 1/7/21.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <Connectivity/Facade.hpp>
#include <memory>
#import "NRMATraceContext.h"

@interface TestNRMATraceContext : XCTestCase
//std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
@end

@implementation TestNRMATraceContext

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testContextWhenPayloadProvided {
#ifdef USE_INTEGRATED_EVENT_MANAGER
    NSString* accountStr = @"accountForTesting";
    NSString* appIdStd = @"appIdForTesting";
    NSString* spanId = @"17172750e6ff8549";
    NSString* traceId = @"spanIdForTesting";
    long long timestamp = 1609970157093;
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:accountStr appID:appIdStd ID:spanId traceID:traceId parentID:spanId trustedAccountKey:@"1"];
#else
    // arrange
    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    std::string accountStr("accountForTesting");
    std::string appIdStd("appIdForTesting");
    std::string traceId("traceIdForTesting");
    std::string spanId("spanIdForTesting");
    long long timestamp = 1609970157093;
    
    // act
    payload->setAccountId(accountStr);
    payload->setAppId(appIdStd);
    payload->setTraceId(traceId);
    payload->setId(spanId);
    payload->setTimestamp(timestamp);
    
#endif
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload: payload];
    
#ifdef USE_INTEGRATED_EVENT_MANAGER
    XCTAssert([accountStr isEqualToString: traceContext.accountId]);
    XCTAssert([appIdStd isEqualToString: traceContext.appId]);
    XCTAssert([traceId isEqualToString: traceContext.traceId]);
    XCTAssert([spanId isEqualToString: traceContext.spanId]);
#else
    // assert
    XCTAssert([[NSString stringWithUTF8String: accountStr.c_str()] isEqualToString: traceContext.accountId]);
    XCTAssert([[NSString stringWithUTF8String: appIdStd.c_str()] isEqualToString: traceContext.appId]);
    XCTAssert([[NSString stringWithUTF8String: traceId.c_str()] isEqualToString: traceContext.traceId]);
    XCTAssert([[NSString stringWithUTF8String: spanId.c_str()] isEqualToString: traceContext.spanId]);
#endif
    XCTAssertEqual(timestamp, traceContext.timestamp);
}

- (void)testContextWhenNoPayload {
    // arrange
    // act
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] init];
    
    // assert
    XCTAssert([traceContext.accountId isEqualToString: @""]);
    XCTAssert([traceContext.appId isEqualToString: @""]);
    XCTAssert([traceContext.traceId isEqualToString: @"00000000000000000000000000000000"]);
    XCTAssert([traceContext.spanId isEqualToString: @"0000000000000000"]);
    XCTAssertEqual(traceContext.timestamp, 0);
    XCTAssertEqual(traceContext.trustedAccount, NRTraceContext);
}
@end
