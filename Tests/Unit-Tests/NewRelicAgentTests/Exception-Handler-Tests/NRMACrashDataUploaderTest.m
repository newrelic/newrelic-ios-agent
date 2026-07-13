//
//  NRMACrashDataUploaderTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 7/10/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRMACrashDataUploader.h"
#import "NRAgentTestBase.h"
#import "NewRelicAgentInternal.h"
#import "NewRelicInternalUtils.h"

#import "NRMAFakeDataHelper.h"
#import "NRMeasurementConsumerHelper.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMATaskQueue.h"
#import "NRMASupportMetricHelper.h"
#import "NRMAExceptionhandlerConstants.h"
#import "NRConstants.h"

@interface NRMACrashDataUploader ()

- (void) uploadFileAtPath:(NSURL*)path;

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL;

- (BOOL) shouldUploadFileWithUniqueIdentifier:(NSString*)path;

- (NSURLRequest*) buildPost;

- (NSArray*) crashReportURLs:(NSError* __autoreleasing*)error;

@end
@interface NRMACrashDataUploaderTest : NRMAAgentTestBase
{
    NRMAMeasurementConsumerHelper* helper;
}
@end

@implementation NRMACrashDataUploaderTest

- (void)setUp
{
    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];

        // Put setup code here. This method is called before the invocation of each test method in the class.
        [NRMASupportMetricHelper processDeferredMetrics];

    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;

    [NRMAMeasurements shutdown];

    [super tearDown];
}

- (id) makeMockURLSession {
    return [self makeMockURLSessionWithStatusCode:200];
}

- (id) makeMockURLSessionWithStatusCode:(NSInteger)statusCode {
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://google.com"] statusCode:statusCode HTTPVersion:@"1.1" headerFields:nil];

    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler(nil, bresponse, nil);
    }] resume];

    return mockNSURLSession;
}

// Remove any crash report files left on disk so each test starts from a clean
// slate (uploadCrashReports drains the whole directory, so a retained report
// from a prior test would otherwise leak into the next one).
- (void) clearCrashReports {
    NSString* reportPath = [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), kNRMA_CR_ReportPath];
    [[NSFileManager defaultManager] removeItemAtPath:reportPath error:nil];
}

- (NSUInteger) remainingCrashReportCountForUploader:(NRMACrashDataUploader*)uploader {
    NSError* error = nil;
    return [[uploader crashReportURLs:&error] count];
}

- (BOOL) consumedMeasurementsContainMetricNamed:(NSString*)name {
    for (id measurement in helper.consumedMeasurements) {
        if ([((NRMANamedValueMeasurement*)measurement).name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (NRMACrashDataUploader*) makeUploaderWithMockStatusCode:(NSInteger)statusCode {
    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    uploader.uploadSession = [self makeMockURLSessionWithStatusCode:statusCode];
    return uploader;
}

// A permanently-rejected (403) crash report must be deleted, not retained for
// pointless retries, and must bump the Crash/Rejected supportability metric.
- (void) testPermanentlyRejectedCrashReportDeletedOn403 {
    [self clearCrashReports];
    [helper.consumedMeasurements removeAllObjects];

    NRMACrashDataUploader* uploader = [self makeUploaderWithMockStatusCode:403];
    [NRMAFakeDataHelper makeFakeCrashReport:1000];

    XCTAssertNoThrow([uploader uploadCrashReports]);

    XCTAssertEqual([self remainingCrashReportCountForUploader:uploader], 0,
                   @"403-rejected crash report should be deleted, not retained.");

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([self consumedMeasurementsContainMetricNamed:kNRMACrashOfflineRejectedMetric],
                  @"Crash/Rejected supportability metric should be emitted on 403.");
}

// 400 Bad Request is also a permanent rejection -> delete.
- (void) testPermanentlyRejectedCrashReportDeletedOn400 {
    [self clearCrashReports];
    [helper.consumedMeasurements removeAllObjects];

    NRMACrashDataUploader* uploader = [self makeUploaderWithMockStatusCode:400];
    [NRMAFakeDataHelper makeFakeCrashReport:1000];

    XCTAssertNoThrow([uploader uploadCrashReports]);

    XCTAssertEqual([self remainingCrashReportCountForUploader:uploader], 0,
                   @"400-rejected crash report should be deleted, not retained.");

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([self consumedMeasurementsContainMetricNamed:kNRMACrashOfflineRejectedMetric],
                  @"Crash/Rejected supportability metric should be emitted on 400.");
}

// Transient server errors (5xx) must be retained for retry and must NOT emit
// the permanent-reject metric.
- (void) testTransientServerErrorCrashReportRetainedOn503 {
    [self clearCrashReports];
    [helper.consumedMeasurements removeAllObjects];

    NRMACrashDataUploader* uploader = [self makeUploaderWithMockStatusCode:503];
    [NRMAFakeDataHelper makeFakeCrashReport:1000];

    XCTAssertNoThrow([uploader uploadCrashReports]);

    XCTAssertEqual([self remainingCrashReportCountForUploader:uploader], 1,
                   @"5xx server error should retain the crash report for a later retry.");

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertFalse([self consumedMeasurementsContainMetricNamed:kNRMACrashOfflineRejectedMetric],
                   @"Crash/Rejected metric must NOT be emitted for a retryable 5xx.");

    [self clearCrashReports];
}

// 429 (rate limited) is transient -> retain, no permanent-reject metric.
- (void) testRateLimitedCrashReportRetainedOn429 {
    [self clearCrashReports];
    [helper.consumedMeasurements removeAllObjects];

    NRMACrashDataUploader* uploader = [self makeUploaderWithMockStatusCode:429];
    [NRMAFakeDataHelper makeFakeCrashReport:1000];

    XCTAssertNoThrow([uploader uploadCrashReports]);

    XCTAssertEqual([self remainingCrashReportCountForUploader:uploader], 1,
                   @"429 rate-limit should retain the crash report for a later retry.");

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertFalse([self consumedMeasurementsContainMetricNamed:kNRMACrashOfflineRejectedMetric],
                   @"Crash/Rejected metric must NOT be emitted for a retryable 429.");

    [self clearCrashReports];
}

// Regression: 500 is the collector's "accepted, will not return" code and must
// still delete (existing success-branch behavior) without emitting the reject metric.
- (void) testServerError500CrashReportDeleted {
    [self clearCrashReports];
    [helper.consumedMeasurements removeAllObjects];

    NRMACrashDataUploader* uploader = [self makeUploaderWithMockStatusCode:500];
    [NRMAFakeDataHelper makeFakeCrashReport:1000];

    XCTAssertNoThrow([uploader uploadCrashReports]);

    XCTAssertEqual([self remainingCrashReportCountForUploader:uploader], 0,
                   @"500 should still delete the crash report (existing behavior).");

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertFalse([self consumedMeasurementsContainMetricNamed:kNRMACrashOfflineRejectedMetric],
                   @"Crash/Rejected metric is for permanent rejects only, not 500.");
}

- (void) testHeaderGeneration {
    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    

    NSURLRequest* request = [uploader buildPost];

    XCTAssertTrue(request != nil);

    XCTAssertTrue([request.allHTTPHeaderFields[NEW_RELIC_APP_VERSION_HEADER_KEY] isEqualToString:@"1.0"]);
    XCTAssertTrue([request.allHTTPHeaderFields[X_APP_LICENSE_KEY_REQUEST_HEADER] isEqualToString:@"token"]);
    XCTAssertTrue([request.allHTTPHeaderFields[NEW_RELIC_OS_NAME_HEADER_KEY] isEqualToString:[NewRelicInternalUtils osName]]);
    XCTAssertTrue([request.URL.absoluteString isEqualToString:@"https://google.com/mobile_crash"]);
}

- (void) testBadURL
{
    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    
    XCTAssertNoThrow([uploader uploadCrashReports], @"this should fail without crashing");

    XCTAssertNoThrow([uploader uploadFileAtPath:nil], @"this should fail without crashing");
    
    NRMACrashDataUploader* uploaderWithCrashCollector = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"test.com"
                                                                               applicationToken:@"token"
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];

     XCTAssertNoThrow([uploaderWithCrashCollector uploadCrashReports], @"this should fail without crashing");

     XCTAssertNoThrow([uploaderWithCrashCollector uploadFileAtPath:nil], @"this should fail without crashing");
}

- (void) testLimitUploads{
    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    uploader.applicationToken = @"token";

    for(int i = 0; i < kNRMAMaxCrashUploadRetry ;i++){
        XCTAssertTrue([uploader shouldUploadFileWithUniqueIdentifier:@"helloWorld"]);
    }
    XCTAssertFalse([uploader shouldUploadFileWithUniqueIdentifier:@"helloWorld"]);
}

-(void) testCrashReportMaxPayloadSizeLimitUpload {
    [helper.consumedMeasurements removeAllObjects];
    
    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    
    [NRMAFakeDataHelper makeFakeCrashReport:21000];

    XCTAssertNoThrow([uploader uploadCrashReports], @"this should fail without crashing");
    
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];
    
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    NSString* fullMetricName = [NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, @"mobile_crash"];
    
    NRMANamedValueMeasurement* foundMeasurement;
    
    for (id measurement in helper.consumedMeasurements) {
        if([((NRMANamedValueMeasurement*)measurement).name isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }

    XCTAssertEqualObjects(foundMeasurement.name, fullMetricName, @"Name is not generated properly.");
}

-(void) testCrashReportMobileCrashSupportabilityMetric {
    [helper.consumedMeasurements removeAllObjects];
    id mockNSURLSession = [self makeMockURLSession];

    NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                              applicationToken:@"token"
                                                                         connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                        useSSL:YES];
    uploader.uploadSession = mockNSURLSession;
    [NRMAFakeDataHelper makeFakeCrashReport:1000];
    
    XCTAssertNoThrow([uploader uploadCrashReports]);

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];
    
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    NSString* fullMetricName = [NSString stringWithFormat:kNRMABytesOutSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, @"mobile_crash"];
    
    NRMANamedValueMeasurement* foundMeasurement;
    
    for (id measurement in helper.consumedMeasurements) {
        if([((NRMANamedValueMeasurement*)measurement).name isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }

    XCTAssertEqualObjects(foundMeasurement.name, fullMetricName, @"Name is not generated properly.");
}

@end
