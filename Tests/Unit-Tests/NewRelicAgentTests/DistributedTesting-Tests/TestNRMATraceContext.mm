//
//  TestNRMATraceContext.mm
//  Agent_Tests
//
//  Created on 1/7/21.
//  Copyright © 2021 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <Connectivity/Facade.hpp>
#import "NRMATraceContext.h"

@interface TestNRMATraceContext : XCTestCase
//std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
@end

@implementation TestNRMATraceContext

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    /*std::unique_ptr<NewRelic::Connectivity::Payload> payload = nullptr;
//    payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
    payload = NewRelic::Connectivity::Facade::getInstance().newPayload();
    payload->setAccountId(std::string("matt"));
    auto theString = payload->getAccountId();
    return;*/
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testContextWhenPayloadProvided {
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
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload: payload];
    
    // assert
    XCTAssert([[NSString stringWithUTF8String: accountStr.c_str()] isEqualToString: traceContext.accountId]);
    XCTAssert([[NSString stringWithUTF8String: appIdStd.c_str()] isEqualToString: traceContext.appId]);
    XCTAssert([[NSString stringWithUTF8String: traceId.c_str()] isEqualToString: traceContext.traceId]);
    XCTAssert([[NSString stringWithUTF8String: spanId.c_str()] isEqualToString: traceContext.spanId]);
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
