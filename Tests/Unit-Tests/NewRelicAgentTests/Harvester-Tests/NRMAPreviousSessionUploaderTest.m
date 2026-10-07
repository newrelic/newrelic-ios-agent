//
//  NRMAPreviousSessionUploaderTest.m
//  Agent_Tests
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "NRMAPreviousSessionUploader.h"
#import "NRMAHarvesterConnection.h"
#import "NRMAHarvestResponse.h"
#import "NRMADataToken.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAAppToken.h"
#import "NRTestConstants.h"

@interface NRMAPreviousSessionUploaderTest : XCTestCase
@end

@implementation NRMAPreviousSessionUploaderTest {
    NRMAPreviousSessionUploader *sut;
    id mockConnection;
    NRMADataToken *dataToken;
}

- (void)setUp {
    [super setUp];

    // -uploadWithConnection:dataToken: reads [NRMAAgentConfiguration connectionInformation],
    // so an agent configuration must exist in-process first.
    [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                    collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                        crashAddress:nil];

    sut = [[NRMAPreviousSessionUploader alloc] init];
    mockConnection = [OCMockObject mockForClass:[NRMAHarvesterConnection class]];
    dataToken = [[NRMADataToken alloc] init];
    dataToken.clusterAgentId = 1;
    dataToken.realAgentId = 1;
}

- (void)tearDown {
    [mockConnection stopMocking];
    [super tearDown];
}

- (NRMAHarvestResponse *)responseWithStatusCode:(int)statusCode {
    NRMAHarvestResponse *response = [[NRMAHarvestResponse alloc] init];
    response.statusCode = statusCode;
    return response;
}

- (void)testNotYetCapturedDoesNotSendAndDoesNotCrash {
    // Nothing captured yet (recovery read still in flight) -- must be a silent
    // no-op, not an attempt, so the next harvest retries.
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
    // Verify no stub was ever configured/invoked on the mock: OCMock will raise
    // on a strict mock if an unexpected message was sent, so simply reaching
    // here without an exception demonstrates sendData: was never called.
}

- (void)testFailedSendStillLatchesAndDoesNotRetry {
    // Current behavior is fire-and-forget: the response from sendData: is
    // never inspected, so even a failed send latches _didUpload and is never
    // retried on a later harvest cycle.
    [sut setLastSessionAttributeJSON:@"{\"foo\":\"bar\"}" eventJSON:@"[{\"eventType\":\"Custom\"}]"];

    [[[mockConnection expect] andReturn:[self responseWithStatusCode:500]] sendData:[OCMArg any]];
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
    [mockConnection verify];

    // No stub configured for a second sendData: -- the strict mock raises if
    // it's invoked again, proving the failed attempt is not retried.
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
}

- (void)testSuccessfulSendLatchesAndDoesNotRetry {
    [sut setLastSessionAttributeJSON:@"{\"foo\":\"bar\"}" eventJSON:@"[{\"eventType\":\"Custom\"}]"];

    [[[mockConnection expect] andReturn:[self responseWithStatusCode:200]] sendData:[OCMArg any]];
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
    [mockConnection verify];

    // Confirmed delivered -- must not be sent again on the next harvest cycle.
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
    [mockConnection verify];
}

- (void)testNothingToSendLatchesWithoutCallingSendData {
    [sut setLastSessionAttributeJSON:@"" eventJSON:@""];

    // No stub configured for sendData: -- the strict mock raises if it's called.
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
}

- (void)testEventsAloneWithNoAttributesAreNotSent {
    // Current behavior treats either side being empty as "nothing to send" --
    // events alone, with no attributes, are skipped rather than sent.
    [sut setLastSessionAttributeJSON:@"" eventJSON:@"[{\"eventType\":\"Custom\"}]"];

    // No stub configured for sendData: -- the strict mock raises if it's called.
    [sut uploadWithConnection:mockConnection dataToken:dataToken];
}

@end
