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

@interface NRMAHexUploader ()
- (void) handledErroredTask:(NSURLSessionTask*)task payload:(id)payload;
@property(strong) NSURLSession* session;
@property(strong) NSMutableArray* pendingPayloads;
@property(assign) NSUInteger inFlightCount;
// Keyed by @(task.taskIdentifier); values are NRMAHexPayload (private to
// NRMAHexUploader.m), accessed here via KVC.
@property(strong) NSMutableDictionary* payloadByTaskId;
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

- (void) testHandledNetworkError {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredTask:OCMOCK_ANY payload:OCMOCK_ANY];

    // A >= 400 response is recorded against the in-flight payload, but the
    // terminal retry/abandon decision is made in didCompleteWithError so it
    // happens exactly once per attempt. Register a payload under the task's
    // identifier so the response/completion handlers can find it.
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost/f"]];
    id payload = [NSClassFromString(@"NRMAHexPayload") new];
    [payload setValue:[@"x" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"data"];

    id mockTask = [OCMockObject niceMockForClass:[NSURLSessionDataTask class]];
    [[[mockTask stub] andReturn:request] originalRequest];
    // The nice mock returns 0 for the unstubbed -taskIdentifier; register the
    // payload under that same identifier so lookups resolve to it.
    @synchronized(self.hexUploader.payloadByTaskId) {
        self.hexUploader.payloadByTaskId[@(0)] = payload;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request
                                                              statusCode:400
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];

    [mockUploader URLSession:nil
                    dataTask:mockTask
          didReceiveResponse:response
           completionHandler:^(NSURLSessionResponseDisposition d){}];
    // Completion of the task is where the recorded HTTP error is acted on.
    [mockUploader URLSession:nil task:mockTask didCompleteWithError:nil];
#pragma clang diagnostic pop

    XCTAssertNoThrow([mockUploader verify]);

    [mockUploader stopMocking];
}

- (void) testNoRetryOnSuccess {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredTask:OCMOCK_ANY payload:OCMOCK_ANY];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:nil
                                                              statusCode:201
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];

    [mockUploader URLSession:nil
                    dataTask:nil
          didReceiveResponse:response
           completionHandler:^(NSURLSessionResponseDisposition d){}];
#pragma clang diagnostic pop

    XCTAssertThrows([mockUploader verify]);

    [mockUploader stopMocking];
}

- (void) testRetryOnFailure {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredTask:OCMOCK_ANY payload:OCMOCK_ANY];

    NSError* error = [NSError errorWithDomain:(NSString*)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorDNSLookupFailed
                                     userInfo:nil];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [mockUploader URLSession:nil task:nil didCompleteWithError:error];
#pragma clang diagnostic pop

    XCTAssertNoThrow([mockUploader verify]);

    [mockUploader stopMocking];
}

- (void) testSuccessSupportMetric {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredTask:OCMOCK_ANY payload:OCMOCK_ANY];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:nil
                                                              statusCode:201
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];
    [mockUploader URLSession:nil
                    dataTask:nil
          didReceiveResponse:response
           completionHandler:^(NSURLSessionResponseDisposition d){}];
#pragma clang diagnostic pop

    XCTAssertThrows([mockUploader verify]);

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat:@"Supportability/Mobile/%@/Native/Collector/f/Output/Bytes", [NewRelicInternalUtils osName]];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");

    // Expected byte count should be 0.
    XCTAssertEqual(measurement.value.longLongValue, 0, @"Byte value doesn't match expected.");

    [mockUploader stopMocking];
}

- (void) testMaxPayloadSizeLimit {
    [helper.consumedMeasurements removeAllObjects];

    self.hexUploader.applicationToken = @"IMTHETOKENNOW";
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredTask:OCMOCK_ANY payload:OCMOCK_ANY];
    
    XCTAssertThrows([mockUploader verify]);

    NSData *fakeData = [NRMAFakeDataHelper makeDataDictionary:21000];
    XCTAssertNoThrow([(NRMAHexUploader*)mockUploader sendData:fakeData]);
    
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

    [mockUploader stopMocking];
}

// Regression: previously sendData: nil'd the HTTPBody on the request before
// passing it to uploadTaskWithRequest:fromData:, then the retry path tried
// to read HTTPBody back and POSTed an empty body — burning sockets + FDs.
// Now the payload is tracked in a parallel dictionary so retries can resend
// the original bytes; the request itself MUST stay body-less because
// NSURLSessionUploadTask warns + strips when a request has both a body and
// `fromData:` bytes.
- (void) testRetryPreservesPayload {
    self.hexUploader.applicationToken = @"TOKEN";
    self.hexUploader.applicationVersion = @"1.0";

    const char* payload = "hello-world-handled-exception-bytes";
    NSData* data = [NSData dataWithBytes:payload length:strlen(payload)];

    [self.hexUploader sendData:data];

    // Bookkeeping is synchronous: by the time sendData: returns, the upload
    // has been launched and its payload recorded. The task may already have
    // failed under the simulator (no listener), but the dict entry persists
    // for the duration of any retry chain — so it must be present here. The
    // dictionary is now keyed by @(task.taskIdentifier), and the original
    // bytes live on the tracked NRMAHexPayload's `data` property.
    NSDictionary* snapshot = nil;
    @synchronized(self.hexUploader.payloadByTaskId) {
        snapshot = [self.hexUploader.payloadByTaskId copy];
    }
    XCTAssertGreaterThanOrEqual(snapshot.count, (NSUInteger)1,
                                @"payload must be tracked for retry");

    BOOL foundOriginalLength = NO;
    for (NSNumber* key in snapshot) {
        NSData* trackedData = [snapshot[key] valueForKey:@"data"];
        if (trackedData.length == data.length) {
            foundOriginalLength = YES;
        }
    }
    XCTAssertTrue(foundOriginalLength,
                  @"a tracked payload must match the original byte length");

    [self.hexUploader invalidate];
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
