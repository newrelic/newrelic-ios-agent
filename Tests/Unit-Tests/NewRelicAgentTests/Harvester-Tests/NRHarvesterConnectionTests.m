//
//  NRMAHarvesterConnectionTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/28/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRHarvesterConnectionTests.h"
#import "NewRelicInternalUtils.h"
#import "NRTestConstants.h"
#import "NewRelicAgentInternal.h"
#import <OCMock/OCMock.h>
#import "NRMANamedValueMeasurement.h"
#import "NRMATaskQueue.h"
#import "NRMAMeasurementEngine.h"
#import "NRMAFakeDataHelper.h"

@implementation NRMAHarvesterConnectionTests

- (void) setUp
{
    [super setUp];

    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];

    connection = [[NRMAHarvesterConnection alloc] init];
    connection.applicationToken = @"app token";
    connection.connectionInformation = [NRMAAgentConfiguration connectionInformation];
}

- (void) tearDown {
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;

    [NRMAMeasurements shutdown];
    [super tearDown];
}

- (void) testCreatePost
{
    NSString* url = @"http://mobile-collector.newrelic.com/foo";
    NSURLRequest* post = [connection createPostWithURI:url message:@"hello world"];

    XCTAssertTrue([post.allHTTPHeaderFields[NEW_RELIC_OS_NAME_HEADER_KEY] isEqualToString:[NewRelicInternalUtils osName]]);
    XCTAssertTrue([post.allHTTPHeaderFields[NEW_RELIC_APP_VERSION_HEADER_KEY] isEqualToString:@"1.0"]);
    XCTAssertTrue([post.allHTTPHeaderFields[X_APP_LICENSE_KEY_REQUEST_HEADER] isEqualToString:@"app token"]);
    XCTAssertNotNil(post, @"expected creation of Post");
    XCTAssertTrue([[post HTTPMethod] isEqualToString:@"POST"], @"method type should be post.");
    XCTAssertTrue([[post URL].absoluteString isEqualToString:url], @"urls should match");
}

- (void) testCreateConnectPost
{
    connection.collectorHost = @"mobile-collector.newrelic.com";
    NSString* url = @"http://mobile-collector.newrelic.com/mobile/v4/connect";
    NSURLRequest* request = [connection createConnectPost:@"hello world"];
    XCTAssertNotNil(request, @"");
    XCTAssertTrue([request.HTTPMethod isEqualToString:@"POST"], @"");
    XCTAssertTrue([request.URL.absoluteString isEqualToString:url], @"should match");
    
    connection.useSSL = YES;
    request = [connection createConnectPost:@"hello2"];
    XCTAssertNotNil(request, @"");
    XCTAssertTrue([[request.URL.absoluteString substringWithRange:NSMakeRange(0, 5)] rangeOfString:@"https"].location != NSNotFound,@"");
}

- (void) testSend {
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://mobile-collector.newrelic.com"] statusCode:404 HTTPVersion:@"1.1" headerFields:nil];
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];
    
    connection.harvestSession = mockNSURLSession;
    
    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);
    
    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler(nil, bresponse, nil);
    }] resume];
    
    connection.serverTimestamp = 1234;
    connection.collectorHost = @"mobile-collector.newrelic.com";

    NSURLRequest* request = [connection createConnectPost:@"unit tests"];
    XCTAssertNotNil(request, @"");

    NRMAHarvestResponse* response = [connection send:request];
    XCTAssertNotNil(response, @"");
    XCTAssertEqual(404, response.statusCode, @"we should be not found!");
    XCTAssertTrue([response.responseBody isEqualToString:@""], @"");

    XCTAssertTrue([response isError], @"");
    XCTAssertTrue(response.statusCode == NOT_FOUND, @"");

    [mockUploadTask stopMocking];
    [mockNSURLSession stopMocking];
}

- (void) testMaxPayloadSizeLimitSendConnect {
    [helper.consumedMeasurements removeAllObjects];

    connection.serverTimestamp = 1234;
    NRMAConnectInformation *connectInfo = [self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native];
    connectInfo.applicationInformation.appName = [NRMAFakeDataHelper makeStringOfSizeInBytes:1000000];
    connection.connectionInformation = connectInfo;
    
    connection.collectorHost = @"mobile-collector.newrelic.com";
    
    NRMAHarvestResponse* response = [connection sendConnect];
    XCTAssertNotNil(response, @"");
    XCTAssertEqual(ENTITY_TOO_LARGE,response.statusCode, @"");
    
    [NRMATaskQueue synchronousDequeue];
    
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    NSString* fullMetricName = [NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, @"connect"];
    
    NRMANamedValueMeasurement* foundMeasurement;
    
    for (id measurement in helper.consumedMeasurements) {
        if([((NRMANamedValueMeasurement*)measurement).name isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }
    
    XCTAssertEqualObjects(foundMeasurement.name, fullMetricName, @"Name is not generated properly.");
}

- (void) testSendData
{
    connection.serverTimestamp = 1234;
    connection.collectorHost = @"mobile-collector.newrelic.com";
    
    NRMAHarvestResponse* response = [connection sendData:[self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native]];
    XCTAssertNotNil(response, @"");
    XCTAssertEqual(FORBIDDEN, response.statusCode, @"");
}

- (void) testMaxPayloadSizeLimitSendData {
    [helper.consumedMeasurements removeAllObjects];

    connection.serverTimestamp = 1234;
    connection.collectorHost = @"mobile-collector.newrelic.com";
    
    NRMAConnectInformation *connectInfo = [self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native];
    connectInfo.applicationInformation.appName = [NRMAFakeDataHelper makeStringOfSizeInBytes:1000000];
    
    NRMAHarvestResponse* response = [connection sendData:connectInfo];
    XCTAssertNotNil(response, @"");
    XCTAssertEqual(ENTITY_TOO_LARGE, response.statusCode, @"");
    
    [NRMATaskQueue synchronousDequeue];
    
    NSString* nativePlatform = [NewRelicInternalUtils osName];
    NSString* platform = [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform];
    NSString* fullMetricName = [NSString stringWithFormat: kNRMAMaxPayloadSizeLimitSupportabilityFormatString, nativePlatform, platform, kNRMACollectorDest, @"data"];
    
    NRMANamedValueMeasurement* foundMeasurement;
    
    for (id measurement in helper.consumedMeasurements) {
        if([((NRMANamedValueMeasurement*)measurement).name isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }
    
    XCTAssertEqualObjects(foundMeasurement.name, fullMetricName, @"Name is not generated properly.");
}

- (void) testSendDisabledAppToken {
    // Set up stub for /data endpoint.
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://staging-mobile-collector.newrelic.com"] statusCode:UNAUTHORIZED HTTPVersion:@"1.1" headerFields:nil];
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    connection.harvestSession = mockNSURLSession;

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler([NSData data], bresponse, nil);
    }] resume];
    // End set up stub for /data endpoint.

    connection.applicationToken = @"disabled-app-token";
    connection.collectorHost= KNRMA_TEST_COLLECTOR_HOST;
    connection.serverTimestamp = 1234;
    connection.useSSL = YES;

    NSURLRequest* request = [connection createConnectPost:@"Unit Test"];
    XCTAssertNotNil(request, @"");
    
    NRMAHarvestResponse* response = [connection send:request];
    XCTAssertNotNil(response, @"");
    
    XCTAssertEqual(UNAUTHORIZED, response.statusCode, @"");
}

- (void) testSendEnabledAppToken {

    // Set up stub for /data endpoint.
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://staging-mobile-collector.newrelic.com"] statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    connection.harvestSession = mockNSURLSession;

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler([NSData data], bresponse, nil);
    }] resume];
    // End set up stub for /data endpoint.

    connection.connectionInformation = [self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native];
    connection.collectorHost = KNRMA_TEST_COLLECTOR_HOST;
    connection.applicationToken = @"app-token";
    connection.useSSL = YES;
    connection.serverTimestamp = 1234;

    
    NRMAHarvestResponse* response= [connection sendConnect];
    XCTAssertNotNil(response, @"");
    
    XCTAssertEqual(response.statusCode,200, @"");
}

- (void) testCollectorCompressionGZip
{
    NSMutableString* message = [[NSMutableString alloc]initWithCapacity:513];
    for (int i = 0; i < 513; i++)
        [message appendFormat:@"a"];
    NSURLRequest* generatedRequest = [connection createPostWithURI:@"helloworld" message:message];

    XCTAssertEqual([generatedRequest.HTTPBody length],14,@"");
    XCTAssertEqualObjects([generatedRequest.allHTTPHeaderFields objectForKey:@"Content-Encoding"], @"deflate", @"");
}

- (void) testCollectorCompression
{
    NSMutableString* message = [[NSMutableString alloc]initWithCapacity:513];
    for (int i = 0; i < 28; i++)
        [message appendFormat:@"a"];
    NSURLRequest* generatedRequest = [connection createPostWithURI:@"helloworld" message:message];

    XCTAssertEqualObjects([generatedRequest.allHTTPHeaderFields objectForKey:@"Content-Encoding"], @"identity", @"");
}

// Is this test failing for you? Do you have Charles running? Try with it turned off.
- (void) testSendSupportMetric {

    NSLog(@"did this (^) test hang? do you have charles running? ಠ_ಠ");

    connection.collectorHost = KNRMA_TEST_COLLECTOR_HOST;
    connection.applicationToken = @"app-token";

    // Set up stub for /data endpoint.
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://staging-mobile-collector.newrelic.com"] statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    connection.harvestSession = mockNSURLSession;

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler([NSData data], bresponse, nil);
    }] resume];
    // End set up stub for /data endpoint.
    
    connection.connectionInformation = [self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native];
    connection.collectorHost = KNRMA_TEST_COLLECTOR_HOST;
    connection.applicationToken = @"app-token";
    connection.useSSL = YES;
    connection.serverTimestamp = 1234;

    [connection sendData: [self createConnectionInformationWithOsName:[NewRelicInternalUtils osName] platform:NRMAPlatform_Native]];

    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([helper.result isKindOfClass:[NRMANamedValueMeasurement class]], @"The result is not a named value.");

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat:@"Supportability/Mobile/%@/Native/Collector/data/Output/Bytes", [NewRelicInternalUtils osName]];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");

    // Expected byte count should not be 0.
    XCTAssertNotEqual(measurement.value.longLongValue, 0, @"Byte value doesn't match expected.");
}

- (NRMAConnectInformation*) createConnectionInformationWithOsName:(NSString*)osName platform:(NRMAApplicationPlatform)platform
{
    NSString* appName = @"test";
    NSString* appVersion = @"1.0";
    NSString* packageId = @"com.test";
    NRMAApplicationInformation* appInfo = [[NRMAApplicationInformation alloc] initWithAppName:appName
                                                                                   appVersion:appVersion
                                                                                     bundleId:packageId];

    NRMADeviceInformation* devInfo = [[NRMADeviceInformation alloc] init];
    devInfo.osName = osName;
    devInfo.osVersion = [NewRelicInternalUtils osVersion];
    devInfo.manufacturer = @"Apple Inc.";
    devInfo.model = [NewRelicInternalUtils deviceModel];
    devInfo.agentName = [NewRelicInternalUtils agentName];
    devInfo.agentVersion = @"2.123";
    devInfo.deviceId =@"DEVICEID-AAAA-BBBB-CCCC-1668CFD67DA1";
    devInfo.platform = platform;
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    
    connectionInformation.applicationInformation = appInfo;
    connectionInformation.deviceInformation = devInfo;
    return connectionInformation;
}
@end
