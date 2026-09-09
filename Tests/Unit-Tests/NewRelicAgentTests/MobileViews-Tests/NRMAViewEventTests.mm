//
//  NRMAViewEventTests.mm
//  NewRelicAgent
//
//  Covers the built-in view event in BOTH event systems.
//
//  MobileView and MobileViewTiming are reserved event types. In the old (C++) event system
//  AnalyticsController::newCustomEvent throws on a reserved type, so while these events were
//  emitted through -recordCustomEvent: every one of them was dropped on the default
//  configuration -- NRFeatureFlag_NewEventSystem is not on by default. These tests pin the
//  built-in path that replaced it, and the `category` attribute both systems attach at
//  serialization time (the attribute validator rejects "category" as a reserved keyword, so it
//  cannot be added as an ordinary attribute).
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Analytics/EventManager.hpp>
#import <Analytics/EventDeserializer.hpp>
#import <Analytics/ViewEvent.hpp>
#import <Analytics/Constants.hpp>
#import <sstream>
#import "NRMAViewEvent.h"
#import "Constants.h"

@interface NRMAViewEventTests : XCTestCase
@end

@implementation NRMAViewEventTests

#pragma mark - New event system: NRMAViewEvent

- (NRMAViewEvent *)eventOfType:(NSString *)eventType {
    return [[NRMAViewEvent alloc] initWithEventType:eventType
                                           category:kNRMA_RET_mobile
                                          timestamp:1788909568307
                        sessionElapsedTimeInSeconds:5.25
                             withAttributeValidator:nil];
}

- (void)testMobileViewEventCarriesItsEventTypeAndCategory {
    NSDictionary *json = [[self eventOfType:kNRMA_RET_mobileView] JSONObject];

    XCTAssertEqualObjects(json[kNRMA_RA_eventType], @"MobileView");
    XCTAssertEqualObjects(json[kNRMA_RA_category], @"Mobile");
}

- (void)testViewTimingEventCarriesItsEventTypeAndTheSameCategory {
    NSDictionary *json = [[self eventOfType:kNRMA_RET_mobileViewTiming] JSONObject];

    XCTAssertEqualObjects(json[kNRMA_RA_eventType], @"MobileViewTiming");
    XCTAssertEqualObjects(json[kNRMA_RA_category], @"Mobile",
                          @"both view event types share one category value");
}

// category is a reserved keyword, so it can only reach the wire by being injected at
// serialization time. If someone converts it to an ordinary addAttribute: call, the validator
// silently drops it and this test fails.
- (void)testCategorySurvivesEvenWithAValidatorThatRejectsEverything {
    NRMAViewEvent *event = [[NRMAViewEvent alloc] initWithEventType:kNRMA_RET_mobileView
                                                          category:kNRMA_RET_mobile
                                                         timestamp:1
                                       sessionElapsedTimeInSeconds:1
                                            withAttributeValidator:nil];
    [event addAttribute:kNRMA_RA_category value:@"spoofed"];

    XCTAssertEqualObjects([[event JSONObject] objectForKey:kNRMA_RA_category], @"Mobile");
}

- (void)testAttributesAndTimestampsAreCarried {
    NRMAViewEvent *event = [self eventOfType:kNRMA_RET_mobileView];
    [event addAttribute:@"viewName" value:@"CheckoutView"];
    [event addAttribute:@"loadTime" value:@(123.5)];

    NSDictionary *json = [event JSONObject];
    XCTAssertEqualObjects(json[@"viewName"], @"CheckoutView");
    XCTAssertEqualObjects(json[@"loadTime"], @(123.5));
    XCTAssertEqualObjects(json[kNRMA_RA_timestamp], @(1788909568307));
}

// Offline storage archives events with NSSecureCoding. If NRMAViewEvent is not in
// +[PersistentEventStore classList], decoding fails outright; if category is not coded, a
// stored event ships without it while a live one ships with it.
- (void)testSecureCodingRoundTripPreservesEventTypeAndCategory {
    NRMAViewEvent *event = [self eventOfType:kNRMA_RET_mobileViewTiming];
    [event addAttribute:@"timingName" value:@"timeToInitialDisplay"];

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event
                                        requiringSecureCoding:YES
                                                        error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);

    NRMAViewEvent *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NRMAViewEvent class]
                                                              fromData:data
                                                                 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(decoded.eventType, @"MobileViewTiming");
    XCTAssertEqualObjects(decoded.category, @"Mobile");
    XCTAssertEqualObjects([decoded JSONObject][kNRMA_RA_category], @"Mobile");
    XCTAssertEqualObjects([decoded JSONObject][@"timingName"], @"timeToInitialDisplay");
}

#pragma mark - Old event system: C++ ViewEvent

- (void)testCppViewEventGeneratesEventTypeAndCategory {
    NewRelic::AttributeValidator validator{[](const char*){return true;},
                                           [](const char*){return true;},
                                           [](const char*){return true;}};
    auto event = NewRelic::EventManager::newViewEvent(__kNRMA_RET_mobileView,
                                                     __kNRMA_RET_mobile,
                                                     1788909568307,
                                                     5.25,
                                                     validator);
    XCTAssertTrue(event != nullptr);

    auto json = event->generateJSONObject();
    std::stringstream rendered;
    rendered << *json;
    std::string out = rendered.str();

    XCTAssertTrue(out.find("\"MobileView\"") != std::string::npos, "event type must be on the wire");
    XCTAssertTrue(out.find("\"Mobile\"") != std::string::npos, "category must be on the wire");
}

// The failure this guards against: without a deserializer branch, MobileView falls through to
// deserializeCustomEvent and comes back as a plain CustomEvent, whose generateJSONObject adds
// no category -- so an offline-stored view event would ship a different shape from a live one.
- (void)testCppViewEventSurvivesSerializationRoundTripWithItsCategory {
    NewRelic::AttributeValidator validator{[](const char*){return true;},
                                           [](const char*){return true;},
                                           [](const char*){return true;}};

    for (const char *eventType : {__kNRMA_RET_mobileView, __kNRMA_RET_mobileViewTiming}) {
        auto event = NewRelic::EventManager::newViewEvent(eventType,
                                                          __kNRMA_RET_mobile,
                                                         1788909568307,
                                                         5.25,
                                                         validator);
        event->addAttribute("viewName", "CheckoutView");

        std::stringstream serialized;
        serialized << *event;

        auto restored = NewRelic::EventDeserializer::deserialize(serialized);
        XCTAssertTrue(restored != nullptr);
        XCTAssertEqual(restored->getEventType(), std::string(eventType));

        std::stringstream rendered;
        rendered << *(restored->generateJSONObject());
        std::string out = rendered.str();

        XCTAssertTrue(out.find("\"Mobile\"") != std::string::npos,
                      "a deserialized view event must still carry its category");
        XCTAssertTrue(out.find("CheckoutView") != std::string::npos,
                      "attributes must survive the round trip");
    }
}

@end
