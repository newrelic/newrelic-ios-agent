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

@interface NRMAHexUploader ()
- (void) handledErroredRequest:(NSURLRequest*)request;

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];

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

//- (void) testNoRetryOnCancel {
//    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
//    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];
//
//    NSError* error = [NSError errorWithDomain:(NSString*)kCFErrorDomainCFNetwork
//                                         code:kCFURLErrorCancelled
//                                     userInfo:nil];
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wnonnull"
//    [mockUploader URLSession:nil task:nil didCompleteWithError:error];
//#pragma clang diagnostic pop
//
//    XCTAssertThrows([mockUploader verify]);
//
//    [mockUploader stopMocking];
//
//}

- (void) testRetryOnFailure {
    id mockUploader = [OCMockObject partialMockForObject:self.hexUploader];
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];

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
    [[mockUploader expect] handledErroredRequest:OCMOCK_ANY];
    
    XCTAssertThrows([mockUploader verify]);

    NSData *fakeData = [NRMAFakeDataHelper makeDataDictionary:21000];
    XCTAssertNoThrow([(NRMAHexUploader*)mockUploader sendData:fakeData]);
    
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

@end
