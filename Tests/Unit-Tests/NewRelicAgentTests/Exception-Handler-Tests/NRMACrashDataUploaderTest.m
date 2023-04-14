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

@interface NRMACrashDataUploader ()

- (void) uploadFileAtPath:(NSURL*)path;

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL;

- (BOOL) shouldUploadFileWithUniqueIdentifier:(NSString*)path;

- (NSURLRequest*) buildPost;

@end
@interface NRMACrashDataUploaderTest : NRMAAgentTestBase
{
    NRMACrashDataUploader* crashUploader;
    NRMAMeasurementConsumerHelper* helper;
}
@end

@implementation NRMACrashDataUploaderTest

- (void)setUp
{
    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];
    
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
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://google.com"] statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    
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
