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
#import "NRMAOfflineStorage.h"
#import "NRMAFlags.h"

@interface NRMAHexUploader ()
- (void) handledErroredRequest:(NSURLRequest*)request error:(NSError*)error;
- (void) sendOfflineStorage;
- (void) persistPayloadForRequestToOfflineStorage:(NSURLRequest*)request;
@property(strong) NSURLSession* session;
@property(strong) NSMutableArray* pendingPayloads;
@property(assign) NSUInteger inFlightCount;
@property(strong) NSMutableDictionary<NSURLRequest*, NSData*>* payloadByRequest;
@property(strong) NRMAOfflineStorage* offlineStorage;
@end

@interface TestHexUploader : NRMAAgentTestBase {
    NRMAMeasurementConsumerHelper* helper;
    NRMAFeatureFlags _originalFlags;
}
@property(strong) NRMAHexUploader* hexUploader;

@end

@implementation TestHexUploader

- (void)setUp {
    [super setUp];

    [NewRelic setPlatform:NRMAPlatform_Native];

    _originalFlags = [NRMAFlags featureFlags];

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

    // Don't let offline-storage state or the feature flag leak between tests.
    // setFeatureFlags: restores flags without emitting an enableFeature support metric.
    [NRMAFlags setFeatureFlags:_originalFlags];
    [NRMAOfflineStorage clearAllOfflineDirectories];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY error:OCMOCK_ANY];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:nil
                                                              statusCode:400
                                                             HTTPVersion:@"1.1"
                                                            headerFields:nil];

    [mockUploader URLSession:nil
                    dataTask:nil
          didReceiveResponse:response
           completionHandler:^(NSURLSessionResponseDisposition d){}];
#pragma clang diagnostic pop

    XCTAssertNoThrow([mockUploader verify]);

    [mockUploader stopMocking];
}

- (void) testNoRetryOnSuccess {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY error:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY error:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY error:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY error:OCMOCK_ANY];
    
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
    // for the duration of any retry chain — so it must be present here.
    NSDictionary<NSURLRequest*, NSData*>* snapshot = nil;
    @synchronized(self.hexUploader.payloadByRequest) {
        snapshot = [self.hexUploader.payloadByRequest copy];
    }
    XCTAssertGreaterThanOrEqual(snapshot.count, (NSUInteger)1,
                                @"payload must be tracked for retry");

    BOOL foundOriginalLength = NO;
    for (NSURLRequest* key in snapshot) {
        // The request itself must NOT carry HTTPBody — that would trip the
        // iOS upload-task warning and strip the body.
        XCTAssertNil(key.HTTPBody, @"upload-task request must have no HTTPBody");
        if (snapshot[key].length == data.length) {
            foundOriginalLength = YES;
        }
    }
    XCTAssertTrue(foundOriginalLength,
                  @"a tracked payload must match the original byte length");

    [self.hexUploader invalidate];
}

// A persist-worthy network-error failure must hand the payload to offline storage so it
// survives until connectivity returns (mirrors SessionReplayReporter / NRMAHarvesterConnection).
- (void) testNetworkErrorPersistsToOfflineStorage {
    [NRMAFlags setFeatureFlags:NRFeatureFlag_OfflineStorage];
    [NRMAOfflineStorage clearAllOfflineDirectories];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://localhost/mobile/f"]];
    NSData* data = [@"hex-report-bytes" dataUsingEncoding:NSUTF8StringEncoding];
    @synchronized(self.hexUploader.payloadByRequest) {
        self.hexUploader.payloadByRequest[request] = data;
    }

    [self.hexUploader persistPayloadForRequestToOfflineStorage:request];

    XCTAssertEqual([self.hexUploader.offlineStorage getAllOfflineData:NO].count, (NSUInteger)1,
                   @"network-error failure must persist the payload to offline storage");
}

// A successful upload triggers a drain: persisted reports are read+cleared and re-sent.
- (void) testSendOfflineStorageDrainsPersistedReports {
    [NRMAFlags setFeatureFlags:NRFeatureFlag_OfflineStorage];
    [NRMAOfflineStorage clearAllOfflineDirectories];

    NSData* data = [@"persisted-hex-report" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.hexUploader.offlineStorage persistDataToDisk:data]);
    XCTAssertEqual([self.hexUploader.offlineStorage getAllOfflineData:NO].count, (NSUInteger)1);

    [self.hexUploader sendOfflineStorage];

    // getAllOfflineData:YES inside sendOfflineStorage clears the directory synchronously.
    XCTAssertEqual([self.hexUploader.offlineStorage getAllOfflineData:NO].count, (NSUInteger)0,
                   @"offline storage must be drained after sendOfflineStorage");

    [self.hexUploader invalidate];
}

// With offline storage disabled, a drain must clear any existing offline directories and
// persist nothing.
- (void) testSendOfflineStorageDisabledClears {
    [NRMAFlags setFeatureFlags:NRFeatureFlag_OfflineStorage];
    [NRMAOfflineStorage clearAllOfflineDirectories];
    NSData* data = [@"x" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.hexUploader.offlineStorage persistDataToDisk:data]);

    [NRMAFlags setFeatureFlags:0];
    [self.hexUploader sendOfflineStorage];

    XCTAssertEqual([self.hexUploader.offlineStorage getAllOfflineData:NO].count, (NSUInteger)0,
                   @"disabled offline storage must be cleared");
}

// Background uploads send their body from a temp file; when the task completes the temp
// file must be removed (the path travels in taskDescription so this also works across an
// app relaunch).
- (void) testCompletionRemovesTempBodyFile {
    NSString* dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"nr-hex-upload"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString* tempPath = [dir stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[@"body" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:tempPath atomically:YES];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tempPath]);

    id task = [OCMockObject niceMockForClass:[NSURLSessionTask class]];
    [[[task stub] andReturn:tempPath] taskDescription];
    [[[task stub] andReturn:nil] originalRequest];
    [[[task stub] andReturn:nil] response];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self.hexUploader URLSession:self.hexUploader.session task:task didCompleteWithError:nil];
#pragma clang diagnostic pop

    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempPath],
                   @"temp upload body must be removed when its task completes");
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
