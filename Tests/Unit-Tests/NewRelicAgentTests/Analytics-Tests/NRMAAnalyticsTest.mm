//
//  NRMAAnalyticsTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 3/20/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NRMAAnalytics+cppInterface.h"
#import <Analytics/AnalyticsController.hpp>
#import <climits>
#import "NRMAFlags.h"
#import "NRMABool.h"
#import "NRLogger.h"
#import "NRMASupportMetricHelper.h"

@interface NRMAAnalyticsTest : XCTestCase
{
}
@end


@interface NRMAAnalytics ()
- (NSString*) sessionAttributeJSONString;
@end
@implementation NRMAAnalyticsTest

- (void)setUp {
    [super setUp];
    [NRLogger setLogLevels:NRLogLevelNone];
    /*  FIXME: don't use PersistentEventsStore/PersistentAttributeStore atm
     const char* dupAttributeStoreName = NewRelic::AnalyticsController::getAttributeDupStoreName();
     const char* dupEventStoreName = NewRelic::AnalyticsController::getEventDupStoreName();
     dupEventStore = new NewRelic::PersistentEventsStore{[NRMAAnalytics getDBStorePath].UTF8String,dupEventStoreName};
     dupAttribStore = new NewRelic::PersistentAttributeStore{[NRMAAnalytics getStorePath].UTF8String,dupAttributeStoreName};
     */
    [NRMAAnalytics clearDuplicationStores];
}

- (void)tearDown {
    [NRMASupportMetricHelper processDeferredMetrics];

    [super tearDown];
}

// Due to the nature of how NSJSONSerialization treats doubles,
// two versions of this test are needed. The first works with the
// new, integrated event manager. The second is the legacy version
// which worked with the older, libMobileAgent version.
- (void) testLargeNumbers {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    bool accepted  = [analytics addCustomEvent:@"myCustomEvent"
                                withAttributes:@{@"bigInt": @(LLONG_MAX),
                                                 @"bigDouble": @(DBL_MAX)}];

    XCTAssertTrue(accepted);

    //1.79769313486232e+308
    //9223372036854775807
    NSString* json = [analytics analyticsJSONString];
    XCTAssertTrue([json containsString:@"9223372036854775807"]);
    XCTAssertTrue([json containsString:@"1.79769313486232e+308"]);
    //NSJSONSerialization can't parse scientific notation because it's bad.
    // See `2.4.  Numbers`  https://www.ietf.org/rfc/rfc4627.txt
    //    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
    //                                                options:0
    //                                                        error:nil];
}

- (void) testLargeNumbersNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    bool accepted  = [analytics addCustomEvent:@"myCustomEvent"
                                withAttributes:@{@"bigInt": @(LLONG_MAX),
                                                 @"bigDouble": @(DBL_MAX)}];

    XCTAssertTrue(accepted);

    NSString* json = [analytics analyticsJSONString];
    NSError *error = nil;
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:&error];

    long long decodedInt = [decode[0][@"bigInt"] longLongValue];
    XCTAssertEqual(decodedInt, @(LLONG_MAX).longLongValue);

    double decodedDouble = [decode[0][@"bigDouble"] doubleValue];
    XCTAssertEqual(decodedDouble, @(DBL_MAX).doubleValue);
}

- (void) testRequestEvents {
    [NRMAFlags enableFeatures:NRFeatureFlag_NetworkRequestEvents];
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile?request=parameter";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:@"application/json"
                                                                                   bytesSent:100];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithSuccessfulResponse:200
                                                                                          bytesReceived:200
                                                                                           responseTime:[timer timeElapsedInSeconds]];

    XCTAssertTrue([analytics addNetworkRequestEvent:requestData withResponse:responseData withPayload:nullptr]);
    
    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"contentType"] isEqualToString:@"application/json"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@200]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertFalse([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);

    [NRMAFlags disableFeatures:NRFeatureFlag_NetworkRequestEvents];
}

- (void) testRequestEventsNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NetworkRequestEvents];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile?request=parameter";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:@"application/json"
                                                                                   bytesSent:100];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithSuccessfulResponse:200
                                                                                          bytesReceived:200
                                                                                           responseTime:[timer timeElapsedInSeconds]];

    XCTAssertTrue([analytics addNetworkRequestEvent:requestData withResponse:responseData withNRMAPayload:nullptr]);

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"contentType"] isEqualToString:@"application/json"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@200]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertFalse([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);

    [NRMAFlags disableFeatures:NRFeatureFlag_NetworkRequestEvents];
}

- (void) testRequestEventHTTPError {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];


    NSString* responseBody = @"helloWorld";
    NSString* responseBodyEncoded = @"aGVsbG9Xb3JsZA==";

    NSString* appDataHeader = @"ToatsBase64EncodedStringSeeThereIsAnEqualSignAtTheEnd=";

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:nil
                                                                                   bytesSent:200];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithHttpError:403
                                                                                 bytesReceived:100
                                                                                  responseTime:[timer timeElapsedInSeconds]
                                                                           networkErrorMessage:@"unauthorized"
                                                                           encodedResponseBody:responseBody
                                                                                 appDataHeader:appDataHeader];

    XCTAssertTrue([analytics addHTTPErrorEvent:requestData withResponse:responseData withPayload:nullptr]);

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertNil(decode[0][@"contentType"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@403]);
    XCTAssertTrue([decode[0][@"errorType"] isEqualToString:@"HTTPError"]);
    XCTAssertTrue([decode[0][@"networkError"] isEqualToString:@"unauthorized"]);
    XCTAssertTrue([decode[0][@"nr.X-NewRelic-App-Data"] isEqualToString:appDataHeader]);
    XCTAssertTrue([decode[0][@"nr.responseBody"] isEqualToString:responseBodyEncoded]);

    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertNil(decode[0][@"networkErrorCode"]);


}

- (void) testRequestEventHTTPErrorNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];


    NSString* responseBody = @"helloWorld";
    NSString* responseBodyEncoded = @"aGVsbG9Xb3JsZA==";

    NSString* appDataHeader = @"ToatsBase64EncodedStringSeeThereIsAnEqualSignAtTheEnd=";

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:nil
                                                                                   bytesSent:200];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithHttpError:403
                                                                                 bytesReceived:100
                                                                                  responseTime:[timer timeElapsedInSeconds]
                                                                           networkErrorMessage:@"unauthorized"
                                                                           encodedResponseBody:responseBody
                                                                                 appDataHeader:appDataHeader];

    XCTAssertTrue([analytics addHTTPErrorEvent:requestData withResponse:responseData withNRMAPayload:nullptr]);

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertNil(decode[0][@"contentType"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@403]);
    XCTAssertTrue([decode[0][@"errorType"] isEqualToString:@"HTTPError"]);
    XCTAssertTrue([decode[0][@"networkError"] isEqualToString:@"unauthorized"]);
    XCTAssertTrue([decode[0][@"nr.X-NewRelic-App-Data"] isEqualToString:appDataHeader]);
    XCTAssertTrue([decode[0][@"nr.responseBody"] isEqualToString:responseBodyEncoded]);

    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertNil(decode[0][@"networkErrorCode"]);


}

- (void) testSetLastInteraction {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    XCTAssertTrue([analytics setLastInteraction:@"Display Banana"]);

    NSString* json = [analytics sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];

    XCTAssertNotNil(decode[@"lastInteraction"]);
    XCTAssertTrue([decode[@"lastInteraction"] isEqualToString:@"Display Banana"]);
}

- (void) testRequestEventNetworkError {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];

    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:@"application/json"
                                                                                   bytesSent:200];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithNetworkError:-1001
                                                                                    bytesReceived:100
                                                                                     responseTime:[timer timeElapsedInSeconds]
                                                                              networkErrorMessage:@"network failure"];

    [analytics addNetworkErrorEvent:requestData withResponse:responseData withPayload:nullptr];
    
    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertTrue([decode[0][@"contentType"] isEqualToString:@"application/json"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"networkErrorCode"] isEqual:@-1001]);
    XCTAssertTrue([decode[0][@"errorType"] isEqualToString:@"NetworkFailure"]);
    XCTAssertTrue([decode[0][@"networkError"] isEqualToString:@"network failure"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertNil(decode[0][@"statusCode"]);
}

- (void) testRequestEventNetworkErrorNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];

    NRTimer* timer = [NRTimer new];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NSString* urlString = @"https://api.newrelic.com/api/v1/mobile";
    NSURL* url = [NSURL URLWithString:urlString];
    [timer stopTimer];

    NRMANetworkRequestData* requestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:url
                                                                                  httpMethod:@"GET"
                                                                              connectionType:@"wifi"
                                                                                 contentType:@"application/json"
                                                                                   bytesSent:200];

    NRMANetworkResponseData* responseData = [[NRMANetworkResponseData alloc] initWithNetworkError:-1001
                                                                                    bytesReceived:100
                                                                                     responseTime:[timer timeElapsedInSeconds]
                                                                              networkErrorMessage:@"network failure"];


    [analytics addNetworkErrorEvent:requestData withResponse:responseData withNRMAPayload:nullptr];
    
    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertTrue([decode[0][@"requestUrl"] isEqualToString:urlString]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"api.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestPath"] isEqualToString:@"/api/v1/mobile"]);
    XCTAssertTrue([decode[0][@"contentType"] isEqualToString:@"application/json"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"bytesSent"] isEqual:@200]);
    XCTAssertTrue([decode[0][@"bytesReceived"] isEqual:@100]);
    XCTAssertTrue([decode[0][@"networkErrorCode"] isEqual:@-1001]);
    XCTAssertTrue([decode[0][@"errorType"] isEqualToString:@"NetworkFailure"]);
    XCTAssertTrue([decode[0][@"networkError"] isEqualToString:@"network failure"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertNil(decode[0][@"statusCode"]);
}

- (void) testCustomEvent {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    BOOL didAddCustomEvent = [analytics addCustomEvent:@"newEventBlah"
                                        withAttributes:@{
        @"blah":@"blah",
        @"Winner":@1}];

    XCTAssertTrue(didAddCustomEvent);

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"newEventBlah"]);
    XCTAssertTrue([decode[0][@"blah"] isEqualToString:@"blah"]);
    XCTAssertTrue([decode[0][@"Winner"] isEqual:@1]);
}

- (void) testCustomEventNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    BOOL didAddCustomEvent = [analytics addCustomEvent:@"newEventBlah"
                                        withAttributes:@{
        @"blah":@"blah",
        @"Winner":@1}];

    XCTAssertTrue(didAddCustomEvent);

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"newEventBlah"]);
    XCTAssertTrue([decode[0][@"blah"] isEqualToString:@"blah"]);
    XCTAssertTrue([decode[0][@"Winner"] isEqual:@1]);
}

- (void) testInteractionEvent {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    [analytics addInteractionEvent:@"newEventBlah" interactionDuration:1.0];

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"Mobile"]);
    XCTAssertTrue([decode[0][@"name"] isEqualToString:@"newEventBlah"]);
    XCTAssertTrue([decode[0][@"category"] isEqualToString:@"Interaction"]);
    XCTAssertTrue([decode[0][@"interactionDuration"] isEqual:@(1.0)]);    
}

- (void) testInteractionEventNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    [analytics addInteractionEvent:@"newEventBlah" interactionDuration:1.0];

    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"Mobile"]);
    XCTAssertTrue([decode[0][@"name"] isEqualToString:@"newEventBlah"]);
    XCTAssertTrue([decode[0][@"category"] isEqualToString:@"Interaction"]);
    XCTAssertTrue([decode[0][@"interactionDuration"] isEqual:@(1.0)]);
}

- (void ) testCustomEventUnicode {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    XCTAssertTrue([analytics addCustomEvent:@"我々は思い出にわならないさ"
                             withAttributes:@{}]);
}

- (void ) testBadAttributes {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    XCTAssertTrue([analytics addCustomEvent:@"我々は思い出にわならないさ"
                             withAttributes:@{@"badAttribute":[NSNull new]}]);
    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertTrue(decode[0][@"badAttribute"] == nil);

}

- (void) testBreadcrumb {

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    XCTAssertFalse([analytics addBreadcrumb:@""
                             withAttributes:nil]);

    XCTAssertFalse([analytics addBreadcrumb:nil
                             withAttributes:nil]);

    XCTAssertTrue([analytics addBreadcrumb:@"testBreadcrumbs"
                            withAttributes:nil]);

    NSString* json = [analytics analyticsJSONString];

    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"MobileBreadcrumb"]);
    XCTAssertTrue([decode[0][@"name"] isEqualToString:@"testBreadcrumbs"]);
}

- (void) testRecordUserAction {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    NRMAUserAction* uiGesture = [NRMAUserActionBuilder buildWithBlock:^(NRMAUserActionBuilder* builder) {
            [builder withActionType:@"Tap"];
            [builder fromMethod:@"Method"];
            [builder fromClass:NSStringFromClass([self class])];
            [builder fromUILabel:@"Label"];
            [builder withAccessibilityId:@"AccessibilityId"];
            [builder atCoordinates:NSStringFromCGPoint(CGPointMake(1, 1))];
            [builder withElementFrame:NSStringFromCGRect(CGRectMake(1, 1, 1, 1))];
    }];
    
    [analytics recordUserAction:uiGesture];

    NSString* json = [analytics analyticsJSONString];

    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"eventType"]);
    XCTAssertTrue([decode[0][@"eventType"] isEqualToString:@"MobileUserAction"]);
    XCTAssertTrue([decode[0][@"actionType"] isEqualToString:@"Tap"]);
    XCTAssertTrue([decode[0][@"accessibility"] isEqualToString:@"AccessibilityId"]);
    XCTAssertTrue([decode[0][@"targetObject"] isEqualToString:@"NRMAAnalyticsTest"]);
    XCTAssertTrue([decode[0][@"methodExecuted"] isEqualToString:@"Method"]);
    XCTAssertTrue([decode[0][@"label"] isEqualToString:@"Label"]);
    XCTAssertTrue([decode[0][@"controlRect"] isEqualToString:@"{{1, 1}, {1, 1}}"]);
    XCTAssertTrue([decode[0][@"touchCoordinates"] isEqualToString:@"{1, 1}"]);
    XCTAssertTrue([decode[0][@"orientation"] isEqualToString:@"Unknown"]);

}

- (void) testRecordEmptyUserAction {
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    NRMAUserAction* uiGesture = [NRMAUserActionBuilder buildWithBlock:^(NRMAUserActionBuilder* builder) {}];
    
    XCTAssertFalse([analytics recordUserAction:uiGesture]);
}

- (void) testRecordNilUserAction {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    
    XCTAssertFalse([analytics recordUserAction:nil]);
}


- (void) testBooleanSessionAttribute {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    [analytics setSessionAttribute:@"aBoolValue" value:[[NRMABool alloc] initWithBOOL:YES]];
    NSString* json = [analytics analyticsJSONString];
    json = [analytics sessionAttributeJSONString];

    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0
                                                                 error:nil];

    XCTAssertTrue([dictionary[@"aBoolValue"] boolValue]);
}

- (void)testBooleanEventAttribute {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    [analytics addEventNamed:@"BooleanAttributes" withAttributes:@{@"thisIsTrue":@(YES),
                                                                   @"thisIsFalse":@(NO)}];
    NSString* json = [analytics analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertTrue([decode[0][@"thisIsTrue"] boolValue]);
    XCTAssertFalse([decode[0][@"thisIsFalse"] boolValue]);
}

- (void) testRemoveAttribute {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    [analytics setSessionAttribute:@"a" value:@4];
    [analytics setSessionAttribute:@"b" value:@6];

    [analytics removeSessionAttributeNamed:@"a"];

    // [JK] I manually stepped through the above code and verified that the underlying analytics attribute store ends up adding both 'a' and 'b', and then removing 'a' leaving only 'b'.
    // TODO figure out how to programmatically confirm this. analyticsJSONString() returns an empty array


    NSString *json = [analytics analyticsJSONString];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wunused-variable"
    NSDictionary *decoded = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil];
#pragma clang diagnostic pop
    //XCTAssertEqual([decoded valueForKey:@"b"], @6, "Expected result to contain key 'b' with value 6");
    //XCTAssertNil([decoded valueForKey:@"a"], "Expected result to NOT contain key 'a'");
}

- (void) testRemoveAllAttributes {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];

    [analytics setSessionAttribute:@"a" value:@4];
    [analytics setSessionAttribute:@"b" value:@6];

    [analytics removeAllSessionAttributes];

    // [JK] I manually stepped through the above code and verified that the underlying analytics attribute store ends up adding both 'a' and 'b', and then removing both.
    // TODO figure out how to programmatically confirm this. analyticsJSONString() returns an empty array

    NSString *json = [analytics analyticsJSONString];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wunused-variable"
    NSDictionary *decoded = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil];
#pragma clang diagnostic pop

    //XCTAssertNil([decoded valueForKey:@"b"], "Expected result to NOT contain key 'b'");
    //  XCTAssertNil([decoded valueForKey:@"a"], "Expected result to NOT contain key 'a'");
}

- (void) testJSONInputs {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    BOOL result = NO;
    NSString* json = @"{\"hello\":\"world\"}";
    NSDictionary* dictionary = @{@"{\"hello\":\"world\"}":@"{\"blahblah\":\"asdasdf\"}"};
    XCTAssertNoThrow(result = [analytics addEventNamed:json withAttributes:dictionary]);
    json = [analytics analyticsJSONString];
    NSError* error = nil;
    [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                    options:NSJSONReadingAllowFragments
                                      error:&error];

    XCTAssertNil(error,@"NSJSONSerializer was unable to serialize json: %@\nWith error: %@",json, error.description);
}

- (void) testJSONEscapeCharacters {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    BOOL result = NO;
    NSString* name = @"pewpew\r\n\v\a\b\r\t\x01\x02\x03\x04\x05\x06\x07\x0B\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x7F";
    NSDictionary* dictionary = @{@"blah\r\n\v\a\b\r\t\x01\x02\x03\x04\x05\x06\x07\x0B\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x7F":@"w\r\n\v\a\b\r\t\x01\x02\x03\x04\x05\x06\x07\x0B\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x7F"};
    XCTAssertNoThrow(result = [analytics addEventNamed:name withAttributes:dictionary]);
    NSString* json = [analytics analyticsJSONString];
    NSError* error = nil;
    [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                    options:NSJSONReadingAllowFragments
                                      error:&error];

    XCTAssertNil(error,@"NSJSONSerializer was unable to serialize json: %@\nWith error: %@",json, error.description);

}



- (void) testDuplicateStore {
    //todo: reenable test (disabled for beta 1, no persistent store)
    //    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    //    [analytics setSessionAttribute:@"12345" value:@5];
    //    [analytics addEventNamed:@"blah" withAttributes:@{@"pew pew":@"asdf"}];
    //    [analytics setSessionAttribute:@"test" value:@"hello"];
    //
    //    NSDictionary* dict = [NRMAAnalytics getLastSessionsAttributes];
    //    NSArray* array = [NRMAAnalytics getLastSessionsEvents];
    //
    //    XCTAssertTrue([dict[@"12345"] isEqual:@5], @"failed to correctly fetch from dup attribute store.");
    //    XCTAssertTrue([dict[@"test"] isEqual:@"hello"],@"failed to correctly fetch from dup attribute store.");
    //    XCTAssertTrue([array[0][@"name"]  isEqualToString: @"blah"], @"failed to correctly fetch dup event store.");
    //
    //    dict = [NRMAAnalytics getLastSessionsAttributes];
    //    array = [NRMAAnalytics getLastSessionsEvents];
    //
    //    XCTAssertTrue(dict.count == 0, @"dup stores should be empty.");
    //    XCTAssertTrue(array.count == 0, @"dup stores should be empty.");
    //
    //    analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    //    dict = [NRMAAnalytics getLastSessionsAttributes];
    //    array = [NRMAAnalytics getLastSessionsEvents];
    //    XCTAssertTrue([dict[@"test"] isEqualToString:@"hello"],@"persistent attribute was not added to the dup store");
    //    XCTAssertTrue(array.count == 0, @"dup events not empty after Analytics persistent data restored.");
}

- (void) testMidSessionHarvest {
    //todo: reenable test (disabled for beta 1, no persistent store)
    //
    //    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    //
    //    [analytics setMaxEventBufferTime:0];
    //
    //    [analytics addEventNamed:@"pewpew" withAttributes:@{@"1":@"hello",@"2":@2}];
    //
    //    [analytics setSessionAttribute:@"12345" value:@5];
    //    [analytics setSessionAttribute:@"123" value:@"123"];
    //
    //    [analytics onHarvestBefore];
    //
    //
    //    NSDictionary* dict = [NRMAAnalytics getLastSessionsAttributes];
    //    NSArray* array = [NRMAAnalytics getLastSessionsEvents];
    //
    //    XCTAssertTrue([dict[@"12345"] isEqual:@5], @"dup store doesn't contain expected value");
    //    XCTAssertTrue([dict[@"123"] isEqualToString:@"123"], @"dup store doesn't contain expected value");
    //
    //    XCTAssertTrue(array.count == 0, @"dup events should have been cleared out on harvest before.");
}

- (void) testBadInput {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    BOOL result;
    //- (BOOL) addInteractionEvent:(NSString*)name interactionDuration:(double)duration_secs;
    XCTAssertNoThrow(result = [analytics addInteractionEvent:nil interactionDuration:-100],@"shouldn't throw ");

    XCTAssertFalse(result,@"Bad input result in a false result");

    //- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes;
    {
        XCTAssertNoThrow(result = [analytics addEventNamed:@"" withAttributes:nil], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addEventNamed:nil withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addEventNamed:nil withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addEventNamed:@"" withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addEventNamed:nil withAttributes:nil], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");
    }

    {
        XCTAssertNoThrow(result = [analytics addCustomEvent:@"" withAttributes:nil], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addCustomEvent:nil withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addCustomEvent:nil withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addCustomEvent:@"" withAttributes:@{}], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics addCustomEvent:nil withAttributes:nil], @"bad input should not throw an exception");

        XCTAssertFalse(result,@"Bad input result in a false result");
    }

    //- (BOOL) setSessionAttribute:(NSString*)name value:(id)value;
    {
        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:@""]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");


    }
    //- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent;
    {

        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:@""]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:@""] );
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics setSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");
    }
    //- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number;
    {
        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:@1]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");
    }


    //- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent;
    {
        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:@1]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:@1]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:@"" value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics incrementSessionAttribute:nil value:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");
    }
    //- (BOOL) removeSessionAttributeNamed:(NSString*)name;
    {
        XCTAssertNoThrow(result = [analytics removeSessionAttributeNamed:@""]);
        XCTAssertFalse(result,@"Bad input result in a false result");

        XCTAssertNoThrow(result = [analytics removeSessionAttributeNamed:nil]);
        XCTAssertFalse(result,@"Bad input result in a false result");

    }

}

@end
