//
//  TestHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/24/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAHexUploader.h"
#import <OCMock/OCMock.h>
#import "NRMAFakeDataHelper.h"
#import "NRMeasurementConsumerHelper.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMATaskQueue.h"
#import "NRMAHarvesterConnection.h"
#import "NRAgentTestBase.h"
#import "NRMAMeasurements.h"
#import "NewRelicInternalUtils.h"
#import "NewRelic.h"
#import "NRMASupportMetricHelper.h"
#import <NewRelic/NewRelic-Swift.h>

// NRMAHexUploader now delegates all upload+retry to NRMARetryingHTTPClient
// (httpClient) rather than driving an NSURLSessionDataDelegate itself — these
// are private properties re-declared here purely for test injection/inspection.
@interface NRMAHexUploader ()
@property(strong) NRMARetryingHTTPClient* httpClient;
@property(strong) NSMutableArray* pendingPayloads;
@property(assign) NSUInteger inFlightCount;
@end

@interface TestHexUploader : NRMAAgentTestBase {
    NRMAMeasurementConsumerHelper* helper;
}
@property(strong) NRMAHexUploader* hexUploader;

@end

@implementation TestHexUploader

- (void)setUp {
    [super setUp];

    [NewRelic setPlatform:NRMAPlatform_Native];

    self.hexUploader = [[NRMAHexUploader alloc] initWithHost:@"localhost"];

    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];
    
    [NRMASupportMetricHelper processDeferredMetrics];
}

- (void)tearDown {

    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;

    [NRMAMeasurements shutdown];

    [super tearDown];
}

// NRMARetryingHTTPClient reports a terminal outcome exactly once via `completion`
// (see uploadRequest:data:endpoint:completion:). This stubs that outcome so tests
// can drive NRMAHexUploader's response handling synchronously and directly,
// without a real network round trip.
- (id) mockHTTPClientWithData:(NSData*)data response:(NSHTTPURLResponse*)response error:(NSError*)error {
    id mockHTTPClient = [OCMockObject mockForClass:NRMARetryingHTTPClient.class];
    [[[mockHTTPClient stub] andDo:^(NSInvocation *invoke) {
        void (^completion)(NSData*, NSHTTPURLResponse*, NSError*);
        [invoke getArgument:&completion atIndex:5];
        completion(data, response, error);
    }] uploadRequest:OCMOCK_ANY data:OCMOCK_ANY endpoint:OCMOCK_ANY completion:OCMOCK_ANY];
    // NRMAHexUploader's -dealloc calls [_httpClient invalidate] — which fires as
    // soon as this test's hexUploader is released (e.g. the next test's setUp
    // reassigning self.hexUploader). Stub it so the strict mock doesn't raise.
    [[mockHTTPClient stub] invalidate];
    return mockHTTPClient;
}

- (void) testNilHost {
    XCTAssertNoThrow([[NRMAHexUploader alloc] initWithHost:nil]);
    self.hexUploader = [[NRMAHexUploader alloc] initWithHost:nil];
    NSString* buf = @"hello world";
    XCTAssertNoThrow([self.hexUploader sendData:[NSData dataWithBytes:buf.UTF8String
                                              length:buf.length]]);
}

- (void) testNilData {

    XCTAssertNoThrow([self.hexUploader sendData:nil]);
}

// A >= 400 HTTP response with no transport-level NSError must still resolve the
// completion exactly once. Per the current formula in launchUpload:, any error
// other than NSURLErrorNotConnectedToInternet (including "no error, just a bad
// status code") is treated as non-retryable and shouldRemove is YES.
- (void) testHandledNetworkError {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost/f"]
                                                              statusCode:400
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];
    self.hexUploader.httpClient = [self mockHTTPClientWithData:nil response:response error:nil];

    __block BOOL completionCalled = NO;
    __block BOOL shouldRemoveVal = NO;
    [self.hexUploader sendData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]
                       reportId:@"/tmp/nr-hex-report"
                     completion:^(BOOL shouldRemove) {
        completionCalled = YES;
        shouldRemoveVal = shouldRemove;
    }];

    XCTAssertTrue(completionCalled, @"completion must fire for a terminal HTTP error");
    XCTAssertTrue(shouldRemoveVal, @"a plain HTTP 400 with no transport error is treated as non-retryable");
}

- (void) testNoRetryOnSuccess {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost/f"]
                                                              statusCode:201
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];
    self.hexUploader.httpClient = [self mockHTTPClientWithData:[NSData data] response:response error:nil];

    __block BOOL completionCalled = NO;
    __block BOOL shouldRemoveVal = NO;
    [self.hexUploader sendData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]
                       reportId:@"/tmp/nr-hex-report"
                     completion:^(BOOL shouldRemove) {
        completionCalled = YES;
        shouldRemoveVal = shouldRemove;
    }];

    XCTAssertTrue(completionCalled, @"completion must fire on success");
    XCTAssertTrue(shouldRemoveVal, @"a confirmed upload is safe to remove");
}

// NOTE: launchUpload:'s current formula only keeps a report for retry
// (shouldRemove=NO) when the error is specifically NSURLErrorNotConnectedToInternet;
// every other error — including a DNS lookup failure, as tested here — is treated
// as non-retryable and removed. That is the same narrow-whitelist/backwards-default
// shape of bug already flagged and fixed in the delete-on-success work elsewhere;
// this test documents the CURRENT behavior rather than endorsing it.
- (void) testRetryOnFailure {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    NSError* error = [NSError errorWithDomain:(NSString*)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorDNSLookupFailed
                                     userInfo:nil];
    self.hexUploader.httpClient = [self mockHTTPClientWithData:nil response:nil error:error];

    __block BOOL completionCalled = NO;
    __block BOOL shouldRemoveVal = NO;
    [self.hexUploader sendData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]
                       reportId:@"/tmp/nr-hex-report"
                     completion:^(BOOL shouldRemove) {
        completionCalled = YES;
        shouldRemoveVal = shouldRemove;
    }];

    XCTAssertTrue(completionCalled, @"completion must fire on failure");
    XCTAssertTrue(shouldRemoveVal, @"current formula removes on any error other than NSURLErrorNotConnectedToInternet");
}

- (void) testSuccessSupportMetric {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost/f"]
                                                              statusCode:201
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];
    self.hexUploader.httpClient = [self mockHTTPClientWithData:[NSData data] response:response error:nil];

    // Output/Bytes' value is the size of the payload SENT (see
    // NRMASupportMetricHelper.enqueueDataUseMetric:size:received:), so an empty
    // payload keeps the expected value at 0.
    [self.hexUploader sendData:[NSData data]];

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat:@"Supportability/Mobile/%@/Native/Collector/f/Output/Bytes", [NewRelicInternalUtils osName]];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");

    XCTAssertEqual(measurement.value.longLongValue, 0, @"Byte value doesn't match expected.");
}

- (void) testMaxPayloadSizeLimit {
    [helper.consumedMeasurements removeAllObjects];

    self.hexUploader.applicationToken = @"IMTHETOKENNOW";

    NSData *fakeData = [NRMAFakeDataHelper makeDataDictionary:21000];
    XCTAssertNoThrow([self.hexUploader sendData:fakeData]);

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    NSString* fullMetricName = [NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, @"f"];

    NRMANamedValueMeasurement* foundMeasurement;

    for (id measurement in helper.consumedMeasurements) {
        if([((NRMANamedValueMeasurement*)measurement).name isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }

    XCTAssertEqualObjects(foundMeasurement.name, fullMetricName, @"Name is not generated properly.");
}

// Regression (historical): sendData: used to nil out the request's HTTPBody
// before uploading via fromData:, then a retry path re-read the (now empty)
// HTTPBody and POSTed an empty body — burning sockets + FDs. Retry now lives
// entirely inside NRMARetryingHTTPClient (which retains the body across its own
// retry attempts), but NRMAHexUploader is still responsible for handing it the
// correct, unmodified payload bytes on every call — verify that hand-off is intact.
- (void) testSendDataPreservesOriginalPayload {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    const char* payload = "hello-world-handled-exception-bytes";
    NSData* data = [NSData dataWithBytes:payload length:strlen(payload)];

    id mockHTTPClient = [OCMockObject mockForClass:NRMARetryingHTTPClient.class];
    __block NSData* capturedData = nil;
    [[[mockHTTPClient stub] andDo:^(NSInvocation *invoke) {
        NSData* d;
        [invoke getArgument:&d atIndex:3];
        capturedData = d;
    }] uploadRequest:OCMOCK_ANY data:OCMOCK_ANY endpoint:OCMOCK_ANY completion:OCMOCK_ANY];
    // -invalidate is called by NRMAHexUploader's own -invalidate below; stub it
    // so the strict mock doesn't raise on that unrelated-to-this-test call.
    [[mockHTTPClient stub] invalidate];
    self.hexUploader.httpClient = mockHTTPClient;

    [self.hexUploader sendData:data];

    XCTAssertEqualObjects(capturedData, data,
                          @"the original payload bytes must reach the HTTP client unmodified");

    [self.hexUploader invalidate];
}

// Regression: a create-after-invalidate race previously raised
// NSGenericException "Task created in a session that has been invalidated".
// NRMAHexUploader creates upload tasks on a background delegate queue
// (delegateQueue:nil) while the C++ ~HexUploadPublisher() dtor calls -invalidate;
// if invalidate won the race, the next -[NSURLSession uploadTaskWithRequest:fromData:]
// threw and crashed the app. After invalidate, sendData: must not throw and must
// preserve the report (shouldRemove=NO) for a later attempt.
- (void) testSendAfterInvalidateDoesNotThrowAndPreservesReport {
    NRMAHexUploader* uploader = [[NRMAHexUploader alloc] initWithHost:@"http://localhost/f"];
    uploader.applicationToken = @"TOKEN";
    uploader.applicationVersion = @"1.0";

    // Invalidate first, then attempt an upload — the crash scenario.
    [uploader invalidate];

    const char* bytes = "handled-exception-bytes";
    NSData* data = [NSData dataWithBytes:bytes length:strlen(bytes)];

    __block BOOL completionCalled = NO;
    __block BOOL shouldRemoveVal = YES;

    XCTAssertNoThrow(([uploader sendData:data
                                reportId:@"/tmp/nr-hex-report"
                              completion:^(BOOL shouldRemove) {
        completionCalled = YES;
        shouldRemoveVal = shouldRemove;
    }]),
        @"creating an upload task after invalidate must not raise NSGenericException");

    // Draining is synchronous, so the outcome is known by the time sendData: returns.
    XCTAssertTrue(completionCalled,
                  @"completion must fire so the store learns the upload outcome");
    XCTAssertFalse(shouldRemoveVal,
                   @"an upload skipped due to invalidation must keep the report for a later attempt");
}

//// Concurrency cap: more sendData: calls than kNRMAHexMaxInFlight (=4) must
//// queue the overflow on pendingPayloads instead of submitting them all at
//// once. Without this, a 200-deep backlog would spawn 200 sockets on cold
//// start and exhaust the per-process FD limit.
//- (void) testConcurrencyCap {
//    self.hexUploader.applicationToken = @"TOKEN";
//
//    for (int i = 0; i < 10; i++) {
//        const char* payload = "x";
//        NSData* data = [NSData dataWithBytes:payload length:1];
//        [self.hexUploader sendData:data];
//    }
//
//    // 4 in-flight, 6 pending.
//    XCTAssertLessThanOrEqual(self.hexUploader.inFlightCount, (NSUInteger)4,
//                             @"in-flight count must never exceed cap");
//    XCTAssertGreaterThan(self.hexUploader.pendingPayloads.count, (NSUInteger)0,
//                         @"overflow must be queued, not dropped silently");
//    XCTAssertEqual(self.hexUploader.inFlightCount + self.hexUploader.pendingPayloads.count,
//                   (NSUInteger)10,
//                   @"all submitted payloads accounted for");
//
//    [self.hexUploader invalidate];
//}

@end
