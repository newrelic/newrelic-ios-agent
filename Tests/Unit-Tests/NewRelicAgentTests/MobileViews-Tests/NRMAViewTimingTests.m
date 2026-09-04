//
//  NRMAViewTimingTests.m
//  NewRelicAgent
//
//  Unit tests for NRMAViewTiming — the validation, capping, and attribute-mapping layer behind
//  +[NewRelic markViewTiming:] and +[NewRelic recordViewTiming:milliseconds:].
//
//  These tests drive the decision layer (-attributesForTimingNamed:...) rather than the emit path,
//  so they need neither a running agent nor a harvester. The emit wrapper on top of it is a single
//  call to +[NewRelic recordCustomEvent:attributes:].
//
//  See docs/superpowers/specs/2026-08-28-mobileview-timing-design.md
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAViewTiming.h"
#import "NRMAFlags.h"
#import "NRMAViewContext.h"
#import "NewRelic.h"

@interface NRMAViewTimingTests : XCTestCase
@end

@implementation NRMAViewTimingTests {
    NRMAViewTiming *_timing;   // fresh instance per test, so cap state never leaks between tests
}

- (void)setUp {
    [super setUp];
    _timing = [[NRMAViewTiming alloc] init];
    // Timing rides the MobileViews flags. Most tests need it on.
    [NewRelic enableFeatures:NRFeatureFlag_AutomaticMobileViews];
}

- (void)tearDown {
    // Both MobileViews flags are opt-in; restore the default so we don't leak flag state.
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NewRelic disableFeatures:NRFeatureFlag_ManualMobileViews];
    _timing = nil;
    [super tearDown];
}

#pragma mark - Helpers

- (NRMAViewTimingSnapshot *)snapshotWithView {
    return [[NRMAViewTimingSnapshot alloc] initWithViewName:@"ProductDetail"
                                            viewInstanceId:@"INSTANCE-1"
                                              previousView:@"SearchResults"
                                                uiPlatform:@"UIKit"
                                                appearTime:CFAbsoluteTimeGetCurrent()
                                            hasCurrentView:YES];
}

- (NRMAViewTimingSnapshot *)snapshotWithoutView {
    return [[NRMAViewTimingSnapshot alloc] initWithViewName:nil
                                            viewInstanceId:nil
                                              previousView:nil
                                                uiPlatform:nil
                                                appearTime:0
                                            hasCurrentView:NO];
}

#pragma mark - Attribute mapping

// The join to MobileView is the whole point: viewInstanceId must survive onto the timing event.
- (void)testTimingCarriesViewIdentityAndRoute {
    NSDictionary *attrs = [_timing attributesForTimingNamed:@"timeToFullDisplay"
                                              milliseconds:842
                                                  snapshot:[self snapshotWithView]
                                                agentOwned:NO];

    XCTAssertNotNil(attrs, @"a valid mark against a current view must produce attributes");
    XCTAssertEqualObjects(attrs[@"timingName"], @"timeToFullDisplay");
    XCTAssertEqualObjects(attrs[@"timingValue"], @842);
    XCTAssertEqualObjects(attrs[@"viewName"], @"ProductDetail");
    XCTAssertEqualObjects(attrs[@"viewInstanceId"], @"INSTANCE-1",
                          @"viewInstanceId is what joins MobileViewTiming back to its MobileView visit");
    XCTAssertEqualObjects(attrs[@"previousView"], @"SearchResults",
                          @"previousView makes timings queryable by route, not only by destination");
    XCTAssertEqualObjects(attrs[@"uiPlatform"], @"UIKit");
    XCTAssertEqualObjects(attrs[@"agentName"], @"iOS");
}

// A caller-supplied duration with no view current still lands; it is simply unattributed.
- (void)testTimingWithoutCurrentViewOmitsViewKeys {
    NSDictionary *attrs = [_timing attributesForTimingNamed:@"timeToFirstByte"
                                              milliseconds:214
                                                  snapshot:[self snapshotWithoutView]
                                                agentOwned:NO];

    XCTAssertNotNil(attrs, @"a caller-supplied duration is valid even with no current view");
    XCTAssertEqualObjects(attrs[@"timingValue"], @214);
    XCTAssertNil(attrs[@"viewName"], @"no view is current, so viewName must be absent rather than empty");
    XCTAssertNil(attrs[@"viewInstanceId"]);
}

#pragma mark - Reserved names

// timeToInitialDisplay is the agent's OOTB series; customer writes to it would make it incomparable.
- (void)testReservedInitialDisplayNameIsRejectedFromPublicAPI {
    NSDictionary *attrs = [_timing attributesForTimingNamed:@"timeToInitialDisplay"
                                              milliseconds:120
                                                  snapshot:[self snapshotWithView]
                                                agentOwned:NO];

    XCTAssertNil(attrs, @"customers must not be able to write the agent-owned timeToInitialDisplay series");
}

- (void)testReservedInitialDisplayNameIsAllowedForAgentOwnedEmission {
    NSDictionary *attrs = [_timing attributesForTimingNamed:@"timeToInitialDisplay"
                                              milliseconds:120
                                                  snapshot:[self snapshotWithView]
                                                agentOwned:YES];

    XCTAssertNotNil(attrs, @"the agent's own OOTB baseline must be able to use the reserved name");
    XCTAssertEqualObjects(attrs[@"timingName"], @"timeToInitialDisplay");
}

#pragma mark - Name validation

- (void)testEmptyNameIsRejected {
    XCTAssertNil([_timing attributesForTimingNamed:@""
                                     milliseconds:100
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO]);
}

- (void)testOverlongNameIsRejected {
    NSString *tooLong = [@"" stringByPaddingToLength:kNRMAViewTimingMaxNameLength + 1
                                          withString:@"x"
                                     startingAtIndex:0];

    XCTAssertNil([_timing attributesForTimingNamed:tooLong
                                     milliseconds:100
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO],
                 @"names beyond the length limit are rejected to bound attribute cardinality");
}

- (void)testNameAtLengthLimitIsAccepted {
    NSString *atLimit = [@"" stringByPaddingToLength:kNRMAViewTimingMaxNameLength
                                          withString:@"x"
                                     startingAtIndex:0];

    XCTAssertNotNil([_timing attributesForTimingNamed:atLimit
                                        milliseconds:100
                                            snapshot:[self snapshotWithView]
                                          agentOwned:NO],
                    @"the limit itself is valid; only names past it are rejected");
}

#pragma mark - Value validation

// A single NaN poisons every average() and percentile() computed over the event type.
- (void)testNaNDurationIsRejected {
    XCTAssertNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                     milliseconds:NAN
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO],
                 @"NaN must never reach NRDB: it silently poisons every aggregate over the event type");
}

- (void)testInfiniteDurationIsRejected {
    XCTAssertNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                     milliseconds:INFINITY
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO]);
}

- (void)testNegativeDurationIsRejected {
    XCTAssertNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                     milliseconds:-1
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO]);
}

- (void)testZeroDurationIsAccepted {
    XCTAssertNotNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                        milliseconds:0
                                            snapshot:[self snapshotWithView]
                                          agentOwned:NO],
                    @"zero is a legitimate measurement, unlike a negative one");
}

// Catches the seconds-passed-where-ms-expected mistake rather than recording a 10-hour view load.
- (void)testDurationAboveCeilingIsRejected {
    XCTAssertNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                     milliseconds:kNRMAViewTimingMaxMilliseconds + 1
                                         snapshot:[self snapshotWithView]
                                       agentOwned:NO]);
}

#pragma mark - Per-view-instance cap

// The default event buffer holds 1000 events; an unguarded mark in cellForRowAt would evict real data.
- (void)testCustomerTimingsAreCappedPerViewInstance {
    NRMAViewTimingSnapshot *snapshot = [self snapshotWithView];

    for (NSUInteger i = 0; i < kNRMAViewTimingMaxPerViewInstance; i++) {
        NSDictionary *attrs = [_timing attributesForTimingNamed:[NSString stringWithFormat:@"mark%lu", (unsigned long)i]
                                                  milliseconds:100
                                                      snapshot:snapshot
                                                    agentOwned:NO];
        XCTAssertNotNil(attrs, @"mark %lu is within the cap and must be accepted", (unsigned long)i);
    }

    XCTAssertNil([_timing attributesForTimingNamed:@"oneTooMany"
                                     milliseconds:100
                                         snapshot:snapshot
                                       agentOwned:NO],
                 @"the mark past the cap must be dropped");
}

- (void)testCapIsPerViewInstanceNotGlobal {
    NRMAViewTimingSnapshot *first = [self snapshotWithView];
    for (NSUInteger i = 0; i < kNRMAViewTimingMaxPerViewInstance; i++) {
        [_timing attributesForTimingNamed:[NSString stringWithFormat:@"mark%lu", (unsigned long)i]
                            milliseconds:100
                                snapshot:first
                              agentOwned:NO];
    }

    NRMAViewTimingSnapshot *second =
        [[NRMAViewTimingSnapshot alloc] initWithViewName:@"Checkout"
                                         viewInstanceId:@"INSTANCE-2"
                                           previousView:@"ProductDetail"
                                             uiPlatform:@"UIKit"
                                             appearTime:CFAbsoluteTimeGetCurrent()
                                         hasCurrentView:YES];

    XCTAssertNotNil([_timing attributesForTimingNamed:@"timeToFullDisplay"
                                        milliseconds:100
                                            snapshot:second
                                          agentOwned:NO],
                    @"exhausting one view's cap must not silence the next view the user visits");
}

// The OOTB baseline must never be the row that gets dropped.
- (void)testAgentOwnedTimingIsNotSubjectToCustomerCap {
    NRMAViewTimingSnapshot *snapshot = [self snapshotWithView];
    for (NSUInteger i = 0; i < kNRMAViewTimingMaxPerViewInstance; i++) {
        [_timing attributesForTimingNamed:[NSString stringWithFormat:@"mark%lu", (unsigned long)i]
                            milliseconds:100
                                snapshot:snapshot
                              agentOwned:NO];
    }

    XCTAssertNotNil([_timing attributesForTimingNamed:@"timeToInitialDisplay"
                                        milliseconds:120
                                            snapshot:snapshot
                                          agentOwned:YES],
                    @"a customer exhausting the cap must not suppress the agent's own baseline row");
}

#pragma mark - Public API gating

// markViewTiming measures from the current view's appear time; with no view there is no zero point.
//
// NRMAViewContext is a shared singleton, so this drives it to a known-empty state rather than
// assuming the suite left it empty: setting a manual view makes the context's current view manual
// whatever it was before, and flushing it then clears the current view outright. Going through the
// context directly rather than +[NewRelic setCurrentView:] keeps the test independent of whether an
// agent is running.
- (void)testMarkWithNoCurrentViewIsRejected {
    [[NRMAViewContext sharedInstance] setCurrentManualView:@"TransientView" attributes:nil];
    [[NRMAViewContext sharedInstance] flushCurrentManualViewOnBackground];

    XCTAssertFalse([_timing markTimingNamed:@"timeToFullDisplay"],
                   @"with no current view there is no zero point; reporting a wrong number is worse than none");
}

- (void)testMarkIsRejectedWhenBothMobileViewFlagsAreDisabled {
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NewRelic disableFeatures:NRFeatureFlag_ManualMobileViews];

    XCTAssertFalse([_timing markTimingNamed:@"timeToFullDisplay"],
                   @"view timing must be gated by the same flags that gate MobileView collection");
    XCTAssertFalse([_timing recordTimingNamed:@"timeToFirstByte" milliseconds:214],
                   @"the caller-supplied path must honor the same gate");
}

@end
