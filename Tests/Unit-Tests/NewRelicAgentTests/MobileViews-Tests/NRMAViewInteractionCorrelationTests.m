//
//  NRMAViewInteractionCorrelationTests.m
//  Agent_Tests
//
//  Correlation between MobileView events and interaction (activity) traces.
//  See docs/superpowers/specs/2026-08-12-views-interactions-correlation-design.md
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRMAViewContext.h"
#import "NRMATraceController.h"
#import "NRMATraceMachine.h"
#import "NRMAActivityTrace.h"
#import "NRMAFlags.h"
#import "NRMAAnalytics.h"
#import "NRMAHarvestController.h"
#import "NRMAMeasurements.h"
#import "NRMATaskQueue.h"
#import "NRLogger.h"
#import "NewRelic.h"
#import "NewRelicAgentInternal.h"

@interface NRMATraceController ()
+ (NRMATraceMachine *)traceMachine;
@end

@interface NRMAViewInteractionCorrelationTests : XCTestCase {
    BOOL _hadNewEventSystem;
}
@end

@implementation NRMAViewInteractionCorrelationTests

- (void)setUp {
    [super setUp];
    [NRLogger setLogLevels:NRLogLevelNone];
    _hadNewEventSystem = [NRMAFlags shouldEnableNewEventSystem];
    [NRMAMeasurements initializeMeasurements];
    [NRMAHarvestController configuration].at_capture.maxTotalTraceCount = 1000;
    [[NRMAViewContext sharedInstance] setCurrentInteractionId:nil name:nil];
}

- (void)tearDown {
    if ([NRMATraceController isTracingActive]) {
        // cleanup rather than completeActivityTrace: tearing down must not emit events.
        [NRMATraceController cleanup];
    }
    [[NRMAViewContext sharedInstance] setCurrentInteractionId:nil name:nil];
    [NRMAFlags disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMAFlags disableFeatures:NRFeatureFlag_ManualMobileViews];
    if (_hadNewEventSystem) {
        [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    } else {
        [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    }
    [NRMAMeasurements shutdown];
    [super tearDown];
}

// These tests use a private NRMAViewContext instance rather than +sharedInstance so that no state
// leaks between cases. Adding a test-only -reset to the production singleton would be worse.
- (NRMAViewContext *)freshContext {
    return [[NRMAViewContext alloc] init];
}

#pragma mark - Forward direction: view events learn the running interaction

- (void)testInteractionAttributesCarryThePublishedIdAndName {
    NRMAViewContext *ctx = [self freshContext];

    [ctx setCurrentInteractionId:@"C0FFEE-1" name:@"Display ProductViewController"];

    NSDictionary *attrs = [ctx interactionAttributes];
    XCTAssertEqualObjects(attrs[@"interactionId"], @"C0FFEE-1");
    XCTAssertEqualObjects(attrs[@"interactionName"], @"Display ProductViewController");
}

- (void)testInteractionAttributesAreEmptyWhenNoInteractionIsRunning {
    NRMAViewContext *ctx = [self freshContext];

    XCTAssertEqual([ctx interactionAttributes].count, 0,
                   @"no interaction has been published yet");
}

// A view event must never carry the id of an interaction that has already completed.
- (void)testClearingTheSlotRemovesTheInteractionAttributes {
    NRMAViewContext *ctx = [self freshContext];
    [ctx setCurrentInteractionId:@"C0FFEE-2" name:@"Display Whatever"];

    [ctx setCurrentInteractionId:nil name:nil];

    XCTAssertEqual([ctx interactionAttributes].count, 0,
                   @"a cleared slot must not leave a stale interactionId on later view events");
}

- (void)testInteractionAttributesOmitANilName {
    NRMAViewContext *ctx = [self freshContext];

    // startTracingWithRootTrace: publishes the id before the real name is known.
    [ctx setCurrentInteractionId:@"C0FFEE-3" name:nil];

    NSDictionary *attrs = [ctx interactionAttributes];
    XCTAssertEqualObjects(attrs[@"interactionId"], @"C0FFEE-3");
    XCTAssertNil(attrs[@"interactionName"]);
}

#pragma mark - Reverse direction: the interaction event learns the view

- (void)testViewCorrelationAttributesUseTheMobileViewKeyNames {
    NRMAViewContext *ctx = [self freshContext];
    [ctx transitionToView:@"ProductView" instanceId:@"instance-A" appearTime:CFAbsoluteTimeGetCurrent()];
    [ctx transitionToView:@"CheckoutView" instanceId:@"instance-B" appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary *attrs = [ctx viewCorrelationAttributes];

    // Deliberately the same key names as the MobileView event schema, so the join is on
    // identically-named attributes rather than on `currentView` (which breadcrumbs use).
    XCTAssertEqualObjects(attrs[@"viewName"], @"CheckoutView");
    XCTAssertEqualObjects(attrs[@"viewInstanceId"], @"instance-B");
    XCTAssertEqualObjects(attrs[@"previousView"], @"ProductView");
    XCTAssertNil(attrs[@"currentView"],
                 @"currentView is the breadcrumb key; a join against MobileView.viewName needs viewName");
}

- (void)testViewCorrelationAttributesAreEmptyBeforeAnyViewAppears {
    NRMAViewContext *ctx = [self freshContext];

    XCTAssertEqual([ctx viewCorrelationAttributes].count, 0,
                   @"with no view set the interaction event gets no placeholder values");
}

- (void)testViewCorrelationAttributesOmitPreviousViewForTheFirstView {
    NRMAViewContext *ctx = [self freshContext];

    [ctx transitionToView:@"LaunchView" instanceId:@"instance-A" appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary *attrs = [ctx viewCorrelationAttributes];
    XCTAssertEqualObjects(attrs[@"viewName"], @"LaunchView");
    XCTAssertNil(attrs[@"previousView"], @"there is no referrer for the first view of a session");
}

#pragma mark - Trace side (uses +sharedInstance, which is what NRMATraceController publishes to)

// Stands up a real NRMAAnalytics behind a mocked NewRelicAgentInternal, the same way
// APIInteractionTraceTest does, so the emitted interaction event can be inspected.
- (id)mockAgentWithAnalytics:(NRMAAnalytics **)outAnalytics {
    id mockAgentInternal = [OCMockObject niceMockForClass:[NewRelicAgentInternal class]];
    NRMAAnalytics *analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    [[[[mockAgentInternal stub] classMethod] andReturn:mockAgentInternal] sharedInstance];
    [[[mockAgentInternal stub] andReturn:analytics] analyticsController];
    *outAnalytics = analytics;
    return mockAgentInternal;
}

- (NSDictionary *)interactionEventFrom:(NRMAAnalytics *)analytics {
    NSString *json = [analytics analyticsJSONString];
    NSArray *decoded = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:0
                                                         error:nil];
    for (NSDictionary *event in [decoded reverseObjectEnumerator]) {
        if ([event isKindOfClass:[NSDictionary class]] &&
            [event[@"category"] isEqualToString:@"Interaction"]) {
            return event;
        }
    }
    return nil;
}

- (void)testStartingAnInteractionPublishesItsIdentityForViewEvents {
    [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];

    XCTAssertNotNil([NewRelic startInteractionWithName:@"Display ProductViewController"]);

    NSDictionary *attrs = [[NRMAViewContext sharedInstance] interactionAttributes];
    XCTAssertTrue([attrs[@"interactionId"] length] > 0,
                  @"MobileView events emitted during this interaction need its id");
    XCTAssertEqualObjects(attrs[@"interactionName"], @"Display ProductViewController");
}

- (void)testCompletingAnInteractionClearsThePublishedIdentity {
    [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NewRelic startInteractionWithName:@"Display ProductViewController"];

    [NRMATraceController completeActivityTrace];

    XCTAssertEqual([[NRMAViewContext sharedInstance] interactionAttributes].count, 0,
                   @"a view event after completion must not carry the finished interaction's id");
}

// The regression test for late binding. An interaction starts at viewDidLoad/viewWillAppear:, when
// the OUTGOING screen is still current; the new screen only becomes current at viewDidAppear:.
// Binding the view at trace start would blame the previous screen for every screen load.
- (void)testInteractionEventIsLateBoundToTheViewThatAppearedDuringIt {
    [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];

    NRMAViewContext *ctx = [NRMAViewContext sharedInstance];
    [ctx transitionToView:@"ProductView" instanceId:@"instance-A" appearTime:CFAbsoluteTimeGetCurrent()];

    [NewRelic startInteractionWithName:@"Display CheckoutViewController"];

    // viewDidAppear: for the screen being loaded lands after the trace is already running.
    [ctx transitionToView:@"CheckoutView" instanceId:@"instance-B" appearTime:CFAbsoluteTimeGetCurrent()];

    [NRMATraceController completeActivityTrace];

    NSDictionary *event = [self interactionEventFrom:analytics];
    XCTAssertNotNil(event, @"an interaction event should have been recorded");
    XCTAssertEqualObjects(event[@"viewName"], @"CheckoutView",
                          @"late binding must attribute the interaction to the screen that loaded");
    XCTAssertEqualObjects(event[@"viewInstanceId"], @"instance-B");
    XCTAssertEqualObjects(event[@"previousView"], @"ProductView");

    [mockAgent stopMocking];
}

// The join guarantee: the id a MobileView event carries is the id the interaction event carries.
- (void)testViewEventsAndTheInteractionEventShareOneInteractionId {
    [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];

    [[NRMAViewContext sharedInstance] transitionToView:@"CheckoutView"
                                           instanceId:@"instance-B"
                                           appearTime:CFAbsoluteTimeGetCurrent()];
    [NewRelic startInteractionWithName:@"Display CheckoutViewController"];

    // What a MobileView event emitted right now would carry.
    NSString *publishedId = [[NRMAViewContext sharedInstance] interactionAttributes][@"interactionId"];
    XCTAssertTrue(publishedId.length > 0);

    [NRMATraceController completeActivityTrace];

    NSDictionary *event = [self interactionEventFrom:analytics];
    XCTAssertEqualObjects(event[@"interactionId"], publishedId,
                          @"both sides must carry the same id or the NRQL join finds nothing");

    [mockAgent stopMocking];
}

#pragma mark - Forward direction, end to end through the manual setCurrentView: producer

- (NSDictionary *)mobileViewAppearEventFrom:(NRMAAnalytics *)analytics {
    NSString *json = [analytics analyticsJSONString];
    NSArray *decoded = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    for (NSDictionary *event in [decoded reverseObjectEnumerator]) {
        if ([event isKindOfClass:[NSDictionary class]] &&
            [event[@"eventType"] isEqualToString:@"MobileView"] &&
            [event[@"appeared"] boolValue]) {
            return event;
        }
    }
    return nil;
}

- (void)testMobileViewEventCarriesTheRunningInteractionIdentity {
    [NRMAFlags enableFeatures:NRFeatureFlag_ManualMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];

    [NewRelic startInteractionWithName:@"Display CheckoutViewController"];
    NSString *publishedId =
        [[NRMAViewContext sharedInstance] interactionAttributes][kNRMAAttributeInteractionId];
    XCTAssertTrue(publishedId.length > 0);

    [NewRelic setCurrentView:@"Checkout" attributes:nil];

    NSDictionary *event = [self mobileViewAppearEventFrom:analytics];
    XCTAssertNotNil(event, @"setCurrentView: should have emitted a MobileView appear event");
    XCTAssertEqualObjects(event[@"interactionId"], publishedId);
    XCTAssertEqualObjects(event[@"interactionName"], @"Display CheckoutViewController");

    [mockAgent stopMocking];
}

- (void)testCallerAttributesCannotOverrideTheInteractionId {
    [NRMAFlags enableFeatures:NRFeatureFlag_ManualMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];

    [NewRelic startInteractionWithName:@"Display CheckoutViewController"];
    NSString *publishedId =
        [[NRMAViewContext sharedInstance] interactionAttributes][kNRMAAttributeInteractionId];

    [NewRelic setCurrentView:@"Checkout" attributes:@{@"interactionId": @"caller-supplied"}];

    NSDictionary *event = [self mobileViewAppearEventFrom:analytics];
    XCTAssertEqualObjects(event[@"interactionId"], publishedId,
                          @"agent-owned correlation keys must win over caller attributes");

    [mockAgent stopMocking];
}

- (void)testMobileViewEventHasNoInteractionIdWhenNothingIsRunning {
    [NRMAFlags enableFeatures:NRFeatureFlag_ManualMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];
    [[NRMAViewContext sharedInstance] setCurrentInteractionId:nil name:nil];

    [NewRelic setCurrentView:@"Checkout" attributes:nil];

    NSDictionary *event = [self mobileViewAppearEventFrom:analytics];
    XCTAssertNotNil(event);
    XCTAssertNil(event[@"interactionId"], @"no interaction was running, so there is nothing to join to");
    XCTAssertNil(event[@"interactionName"]);

    [mockAgent stopMocking];
}

- (void)testNoCorrelationWhenBothMobileViewsFlagsAreOff {
    [NRMAFlags disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMAFlags disableFeatures:NRFeatureFlag_ManualMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];
    NRMAAnalytics *analytics = nil;
    id mockAgent = [self mockAgentWithAnalytics:&analytics];

    [[NRMAViewContext sharedInstance] transitionToView:@"CheckoutView"
                                           instanceId:@"instance-B"
                                           appearTime:CFAbsoluteTimeGetCurrent()];
    [NewRelic startInteractionWithName:@"Display CheckoutViewController"];

    XCTAssertEqual([[NRMAViewContext sharedInstance] interactionAttributes].count, 0,
                   @"nothing should be published while MobileViews is off");

    [NRMATraceController completeActivityTrace];

    NSDictionary *event = [self interactionEventFrom:analytics];
    XCTAssertNotNil(event, @"the interaction event itself is unchanged by this feature");
    XCTAssertNil(event[@"viewName"], @"a default-configured agent must emit no view attributes");
    XCTAssertNil(event[@"interactionId"]);

    [mockAgent stopMocking];
}

@end
