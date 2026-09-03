//
//  NRMAViewContextChurnTests.m
//  NewRelicAgent
//
//  Regression tests for two bugs found by replaying a captured NRTestApp session through the flow
//  renderer, both triggered reliably by SwiftUI TabView switches:
//
//    A. The visible-view stack leaked. Synthesizing a re-appearance overwrote the uncovered entry's
//       instanceId with a fresh UUID, but that id is the key -removeVisibleViewLocked: matches on and
//       only the producer knows it. The entry became unremovable, so a screen the user had left could
//       be "uncovered" and resurrected minutes later, stealing the referrer of whatever appeared next.
//       Observed: ChartsView resurrected 3.3s after the tab bar was dismissed, twice.
//
//    B. Construction churn synthesized phantom back-navigation. SwiftUI delivers onAppear for an
//       incoming tab, onDisappear for that same view 8-16ms later, then onAppear again with a new
//       identity. The middle disappearance is the top of the stack going away, so it synthesized a
//       re-appearance of the previous tab -- a back-navigation the user never performed, on every
//       single tab switch.
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

/// Comfortably past kNRMAMinDwellMs, so a disappearance reads as a real one rather than as churn.
static const NSTimeInterval kDwellPastThreshold = 0.15;

@interface NRMAViewContextChurnTests : XCTestCase
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

- (void)appear:(NSString *)name instance:(NSString *)instanceId {
    [_context transitionToView:name
                    instanceId:instanceId
                    appearTime:CFAbsoluteTimeGetCurrent()
                      platform:@"SwiftUI"];
}

- (NSString *)currentView {
    return [_context referrerAttributes][@"currentView"];
}

- (NSString *)previousView {
    return [_context referrerAttributes][@"previousView"];
}

#pragma mark - A: the stack must not leak resurrected entries

// After a screen is resurrected by synthesis, its own later disappearance must still remove it.
- (void)testResurrectedViewIsStillRemovableByItsOriginalInstanceId {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Charts" instance:@"ID-CHARTS"];

    // Charts was genuinely on screen, so its disappearance uncovers Dashboard and synthesizes.
    [NSThread sleepForTimeInterval:kDwellPastThreshold];
    [_context viewDidDisappearNamed:@"Charts" instanceId:@"ID-CHARTS"];
    XCTAssertEqualObjects([self currentView], @"Dashboard",
                          @"the uncovered screen must become current -- this is the synthesis working");

    // Dashboard now really goes away, reporting the id it was pushed with. If synthesis replaced that
    // key, this removal silently does nothing and the entry is stranded.
    [NSThread sleepForTimeInterval:kDwellPastThreshold];
    [_context viewDidDisappearNamed:@"Dashboard" instanceId:@"ID-DASH"];

    // Nothing should remain to uncover. A stranded Dashboard would resurface here instead of Profile
    // staying current.
    [self appear:@"Profile" instance:@"ID-PROF"];
    [NSThread sleepForTimeInterval:kDwellPastThreshold];
    [_context viewDidDisappearNamed:@"Profile" instanceId:@"ID-PROF"];

    XCTAssertEqualObjects([self currentView], @"Profile",
                          @"a screen removed by its original instanceId must not be resurrected later");
}

#pragma mark - B: churn must not synthesize a back-navigation

// The observed TabView pattern: incoming tab appears, vanishes ~10ms later, appears again.
- (void)testSubDwellDisappearanceDoesNotSynthesizeBackNavigation {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [NSThread sleepForTimeInterval:kDwellPastThreshold];

    [self appear:@"Form" instance:@"ID-FORM-1"];
    // No sleep: Form is gone within the dwell window, exactly as SwiftUI reports it.
    [_context viewDidDisappearNamed:@"Form" instanceId:@"ID-FORM-1"];

    XCTAssertEqualObjects([self currentView], @"Form",
                          @"churn must not hand the current view back to the previous tab");
    XCTAssertNotEqualObjects([self currentView], @"Dashboard",
                             @"a phantom return to Dashboard is the bug: the user never went back");
}

// A real disappearance must still synthesize, or the SwiftUI pop case this exists for regresses.
- (void)testDisappearancePastDwellStillSynthesizes {
    [self appear:@"Dashboard" instance:@"ID-DASH"];
    [self appear:@"Form" instance:@"ID-FORM"];

    [NSThread sleepForTimeInterval:kDwellPastThreshold];
    [_context viewDidDisappearNamed:@"Form" instanceId:@"ID-FORM"];

    XCTAssertEqualObjects([self currentView], @"Dashboard",
                          @"popping back to a SwiftUI view still needs the synthesized appearance");
    XCTAssertEqualObjects([self previousView], @"Form",
                          @"and the screen just left is its referrer");
}

#pragma mark - B: a view replacing itself keeps its referrer

// The second half of the churn pattern: Form appears again with a new identity. It must not become
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
