//
//  NRMAViewContextChurnTests.m
//  NewRelicAgent
//
//  How NRMAViewContext behaves under the rapid appear/disappear pattern SwiftUI produces on a
//  TabView switch: onAppear for the incoming tab, onDisappear for that same view 8-16ms later, then
//  onAppear again with a new identity.
//
//  The context used to suppress re-appearance synthesis when the departing view had been visible for
//  less than a 100ms minimum dwell, on the grounds that such a pair was construction churn and
//  synthesizing from it manufactured a back-navigation the user never performed. That threshold has
//  been removed: the agent no longer decides which appearances were real, so a disappearance
//  synthesizes from whatever it uncovered however briefly the departing view was on screen. The
//  consequence is an extra `reappeared` row per tab switch, which is deliberate -- these tests pin it
//  so it cannot be reintroduced as a threshold by accident.
//
//  Also covers the stack-leak bug found alongside it: synthesizing a re-appearance overwrote the
//  uncovered entry's instanceId with a fresh UUID, but that id is the key -removeVisibleViewLocked:
//  matches on and only the producer knows it. The entry became unremovable, so a screen the user had
//  left could be "uncovered" and resurrected minutes later, stealing the referrer of whatever
//  appeared next. Observed: ChartsView resurrected 3.3s after the tab bar was dismissed, twice.
//
//  Each test drives its own NRMAViewContext instance rather than the singleton, so a leaked stack
//  entry cannot cross from one case into the next -- which is the very failure mode under test.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAViewContext.h"
#import "NRMAFlags.h"
#import "NewRelic.h"

@interface NRMAViewContextChurnTests : XCTestCase
@end

// The context's own reporting hook for a completed manual visit, declared here so a subclass can
// capture what it reports rather than it going to an analytics controller that tests do not have.
@interface NRMAViewContext (RecordingHook)
- (void)recordMobileView:(NSString *)name
              instanceId:(NSString *)instanceId
            previousView:(nullable NSString *)previousView
  previousViewInstanceId:(nullable NSString *)previousViewInstanceId
             timeVisible:(nullable NSNumber *)timeVisibleMs
             customAttrs:(nullable NSDictionary<NSString *, id> *)customAttrs;
@end

@interface NRMARecordingViewContext : NRMAViewContext
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recorded;
@end

@implementation NRMARecordingViewContext
- (void)recordMobileView:(NSString *)name
              instanceId:(NSString *)instanceId
            previousView:(NSString *)previousView
  previousViewInstanceId:(NSString *)previousViewInstanceId
             timeVisible:(NSNumber *)timeVisibleMs
             customAttrs:(NSDictionary<NSString *, id> *)customAttrs {
    if (!self.recorded) { self.recorded = [NSMutableArray array]; }
    [self.recorded addObject:@{ @"viewName": name ?: @"",
                                @"viewInstanceId": instanceId ?: @"",
                                @"previousView": previousView ?: @"" }];
}
@end

@implementation NRMAViewContextChurnTests {
    NRMAViewContext *_context;
}

- (void)setUp {
    [super setUp];
    _context = [[NRMAViewContext alloc] init];
    [NewRelic enableFeatures:NRFeatureFlag_AutomaticMobileViews];
}

- (void)tearDown {
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    _context = nil;
    [super tearDown];
}

#pragma mark - Helpers

// appearTime comes from +monotonicNow because that is the clock the context documents for every view
// timestamp; a wall-clock value has an unrelated epoch and is not interchangeable with it.
- (void)appear:(NSString *)name instance:(NSString *)instanceId {
    [_context transitionToView:name
                    instanceId:instanceId
                    appearTime:[NRMAViewContext monotonicNow]
                      platform:@"SwiftUI"];
}

- (NSString *)currentView {
    return [_context referrerAttributes][@"currentView"];
}

- (NSString *)previousView {
    return [_context referrerAttributes][@"previousView"];
}

#pragma mark - The stack must not leak resurrected entries

// After a screen is resurrected by synthesis, its own later disappearance must still remove it.
- (void)testResurrectedViewIsStillRemovableByItsOriginalInstanceId {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Charts" instance:@"ID-CHARTS"];

    // Charts going away uncovers Dashboard, which synthesizes a re-appearance.
    [_context viewDidDisappearNamed:@"Charts" instanceId:@"ID-CHARTS"];
    XCTAssertEqualObjects([self currentView], @"Dashboard",
                          @"the uncovered screen must become current -- this is the synthesis working");

    // Dashboard now really goes away, reporting the id it was pushed with. If synthesis replaced that
    // key, this removal silently does nothing and the entry is stranded.
    [_context viewDidDisappearNamed:@"Dashboard" instanceId:@"ID-DASH"];

    // Nothing should remain to uncover. A stranded Dashboard would resurface here instead of Profile
    // staying current.
    [self appear:@"Profile" instance:@"ID-PROF"];
    [_context viewDidDisappearNamed:@"Profile" instanceId:@"ID-PROF"];

    XCTAssertEqualObjects([self currentView], @"Profile",
                          @"a screen removed by its original instanceId must not be resurrected later");
}

#pragma mark - Synthesis is not gated on how long the view was visible

// The observed TabView pattern: the incoming tab appears and vanishes within milliseconds. With no
// minimum dwell, that disappearance synthesizes from what it uncovered like any other.
- (void)testDisappearanceImmediatelyAfterAppearingStillSynthesizes {
    [self appear:@"Dashboard" instance:@"ID-DASH"];

    [self appear:@"Form" instance:@"ID-FORM-1"];
    // No delay: Form is gone within milliseconds, exactly as SwiftUI reports it.
    [_context viewDidDisappearNamed:@"Form" instanceId:@"ID-FORM-1"];

    XCTAssertEqualObjects([self currentView], @"Dashboard",
                          @"a brief visit must synthesize like any other -- no dwell threshold suppresses it");
    XCTAssertEqualObjects([self previousView], @"Form",
                          @"and the screen just left is its referrer");
}

// The same for a view that was on screen long enough that no threshold would ever have applied, so a
// reintroduced guard cannot pass this suite by making both cases behave alike.
- (void)testDisappearanceAfterDwellingStillSynthesizes {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Form" instance:@"ID-FORM"];

    [NSThread sleepForTimeInterval:0.15];
    [_context viewDidDisappearNamed:@"Form" instanceId:@"ID-FORM"];

    XCTAssertEqualObjects([self currentView], @"Dashboard",
                          @"popping back to a SwiftUI view still needs the synthesized appearance");
    XCTAssertEqualObjects([self previousView], @"Form",
                          @"and the screen just left is its referrer");
}

#pragma mark - A resurfaced screen keeps its visit's instance id

// The uncovered entry is a visit that is still open: its producer will report it, under the id it
// was pushed with. Making it current under a fresh UUID gave the next screen a
// previousViewInstanceId that no event carries -- observed on 10 of 20 NRTestApp visits.
- (void)testResurfacedScreenIsCurrentUnderItsOwnInstanceId {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Charts" instance:@"ID-CHARTS"];

    [_context viewDidDisappearNamed:@"Charts" instanceId:@"ID-CHARTS"];

    XCTAssertEqualObjects([_context referrerAttributes][@"currentViewInstanceId"], @"ID-DASH");
}

#pragma mark - Controller departures: covered vs leaving
//
// A view controller reports viewDidDisappear: *before* the next screen's viewDidAppear:, the reverse
// of SwiftUI's onAppear/onDisappear. So "the top disappeared" says nothing about what is visible
// next. Inside a SwiftUI NavigationView the outer host stays on the stack underneath, and both a
// push and a pop "uncovered" it -- AutoPushedDetailScreen reported SwiftUIContentView as its referrer
// instead of the screen it was pushed from, and so did every return to that screen.

// Push: the departing screen is only covered, so it is still the referrer for what appears next.
- (void)testCoveredDepartureDoesNotResurfaceWhatIsBeneath {
    [self appear:@"List" instance:@"ID-LIST"];
    [self appear:@"Demo" instance:@"ID-DEMO"];

    [_context viewDidDisappearNamed:@"Demo" instanceId:@"ID-DEMO" departure:NRMAViewDepartureCovered];
    [self appear:@"Detail" instance:@"ID-DETAIL"];

    XCTAssertEqualObjects([self previousView], @"Demo");
    XCTAssertEqualObjects([_context referrerAttributes][@"previousViewInstanceId"], @"ID-DEMO");
}

// Pop: the uncovered controller's own viewDidAppear: follows in the same main-queue turn, and it
// must see the screen just left as its referrer, not whatever the stack held further down.
- (void)testLeavingDepartureYieldsToARealAppearance {
    [self appear:@"List" instance:@"ID-LIST"];
    [self appear:@"Detail" instance:@"ID-DETAIL"];

    [_context viewDidDisappearNamed:@"Detail" instanceId:@"ID-DETAIL" departure:NRMAViewDepartureLeaving];
    [self appear:@"Demo" instance:@"ID-DEMO-2"];
    [self drainMainQueue];

    XCTAssertEqualObjects([self currentView], @"Demo");
    XCTAssertEqualObjects([self previousView], @"Detail");
}

// Pop to something that will not re-announce itself (an untracked NavigationView root, a presenter
// under a dismissed sheet): the screen beneath does become current, once nothing else has.
- (void)testLeavingDepartureResurfacesWhenNothingAppears {
    [self appear:@"List" instance:@"ID-LIST"];
    [self appear:@"Detail" instance:@"ID-DETAIL"];

    [_context viewDidDisappearNamed:@"Detail" instanceId:@"ID-DETAIL" departure:NRMAViewDepartureLeaving];
    [self drainMainQueue];

    XCTAssertEqualObjects([self currentView], @"List");
    XCTAssertEqualObjects([_context referrerAttributes][@"currentViewInstanceId"], @"ID-LIST");
    XCTAssertEqualObjects([self previousView], @"Detail");
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:1.0];
}

#pragma mark - A manual view replaced by an automatic screen is reported

// A manual view's event is emitted when its visit ends. That used to happen only when another
// setCurrentView: replaced it (or a background flush found it still current) -- an automatic screen
// appearing overwrote it silently, so the visit was never reported, and yet the new screen still named
// it as previousView under an id no event carried. Seen as NRTestApp's "Checkout" and ExpensesTracker's
// "Side Menu".
- (void)testManualViewReplacedByAnAutomaticScreenIsReported {
    NRMARecordingViewContext *context = [[NRMARecordingViewContext alloc] init];
    [context transitionToView:@"Dashboard" instanceId:@"ID-DASH"
                   appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];
    [context setCurrentManualView:@"Side Menu" attributes:nil];
    NSString *manualId = [context referrerAttributes][@"currentViewInstanceId"];

    [context transitionToView:@"Income" instanceId:@"ID-INCOME"
                   appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];

    XCTAssertEqual(context.recorded.count, 1u);
    XCTAssertEqualObjects(context.recorded.firstObject[@"viewName"], @"Side Menu");
    XCTAssertEqualObjects(context.recorded.firstObject[@"viewInstanceId"], manualId);
    XCTAssertEqualObjects(context.recorded.firstObject[@"previousView"], @"Dashboard");
    // And the screen that replaced it names that very visit as its referrer.
    XCTAssertEqualObjects([context referrerAttributes][@"previousView"], @"Side Menu");
    XCTAssertEqualObjects([context referrerAttributes][@"previousViewInstanceId"], manualId);
}

// Once closed out by the automatic screen, the manual visit is over: nothing reports it again.
- (void)testManualViewClosedByAnAutomaticScreenIsNotReportedTwice {
    NRMARecordingViewContext *context = [[NRMARecordingViewContext alloc] init];
    [context setCurrentManualView:@"Checkout" attributes:nil];
    [context transitionToView:@"Home" instanceId:@"ID-HOME"
                   appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];
    [context transitionToView:@"Detail" instanceId:@"ID-DETAIL"
                   appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];
    [context flushCurrentManualViewOnBackground];

    XCTAssertEqual(context.recorded.count, 1u, @"one visit, one event: %@", context.recorded);
}

// An automatic screen replacing an automatic screen is the tracker's business, not the context's.
- (void)testAutomaticTransitionsRecordNothingThemselves {
    NRMARecordingViewContext *context = [[NRMARecordingViewContext alloc] init];
    [context transitionToView:@"A" instanceId:@"ID-A" appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];
    [context transitionToView:@"B" instanceId:@"ID-B" appearTime:[NRMAViewContext monotonicNow] platform:@"UIKit"];

    XCTAssertEqual(context.recorded.count, 0u);
}

#pragma mark - A view replacing itself keeps its referrer

// The second half of the TabView pattern: Form appears again with a new identity. It must not become
// its own previousView, which would draw a navigation from a screen to itself.
- (void)testViewReplacingItselfKeepsItsReferrer {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Form" instance:@"ID-FORM-1"];
    [self appear:@"Form" instance:@"ID-FORM-2"];

    XCTAssertEqualObjects([self currentView], @"Form");
    XCTAssertEqualObjects([self previousView], @"Dashboard",
                          @"a new instance of the same screen must not overwrite the referrer with itself");
}

@end
