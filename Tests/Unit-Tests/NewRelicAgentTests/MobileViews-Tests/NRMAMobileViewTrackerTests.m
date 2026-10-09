//
//  NRMAMobileViewTrackerTests.m
//  NewRelicAgent
//
//  The two questions the UIKit producer asks before it opens a visit for a controller: is this a
//  class that is never a screen, and is the controller's view actually on screen.
//
//  The second exists because UIKit's viewDidAppear: does not mean "the user can see this". A child
//  controller parked off-screen -- ExpensesTracker's side-menu drawer, constrained to leading =
//  -width until it is opened -- receives viewDidAppear: along with its parent. It was reported as
//  one 66-second visit per Home visit while the user saw it for about a second, and as the most
//  recent appearance it became the referrer of the next tab switch.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "NRMAMobileViewTracker.h"

@interface NRMAMobileViewTrackerTests : XCTestCase
@end

@implementation NRMAMobileViewTrackerTests {
    UIWindow *_window;
    UIViewController *_root;
}

- (void)setUp {
    [super setUp];
    _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 400, 800)];
    // A window is hidden until shown, and a hidden window hides everything in it -- which would make
    // every "not on screen" case below pass for the wrong reason.
    _window.hidden = NO;
    _root = [[UIViewController alloc] init];
    _root.view.frame = _window.bounds;
    [_window addSubview:_root.view];
}

- (void)tearDown {
    [_root.view removeFromSuperview];
    _root = nil;
    _window = nil;
    [super tearDown];
}

/// A child whose view sits at `frame` in the root's coordinate space.
- (UIViewController *)childAt:(CGRect)frame {
    UIViewController *child = [[UIViewController alloc] init];
    [_root addChildViewController:child];
    child.view.frame = frame;
    [_root.view addSubview:child.view];
    [child didMoveToParentViewController:_root];
    return child;
}

#pragma mark - Visibility

- (void)testAControllerFillingTheWindowIsOnScreen {
    XCTAssertTrue(NRMA_IsControllerViewOnScreen(_root));
}

- (void)testAChildInsideTheWindowIsOnScreen {
    XCTAssertTrue(NRMA_IsControllerViewOnScreen([self childAt:CGRectMake(0, 400, 400, 400)]));
}

// The drawer: parked entirely to the left of the window.
- (void)testAChildParkedOffScreenIsNotOnScreen {
    XCTAssertFalse(NRMA_IsControllerViewOnScreen([self childAt:CGRectMake(-280, 0, 280, 800)]));
}

// Half-open drawer, or a card peeking in: any visible area counts.
- (void)testAChildPartlyInsideTheWindowIsOnScreen {
    XCTAssertTrue(NRMA_IsControllerViewOnScreen([self childAt:CGRectMake(-140, 0, 280, 800)]));
}

- (void)testAHiddenChildIsNotOnScreen {
    UIViewController *child = [self childAt:CGRectMake(0, 0, 400, 400)];
    child.view.hidden = YES;
    XCTAssertFalse(NRMA_IsControllerViewOnScreen(child));
}

- (void)testAChildInsideAHiddenContainerIsNotOnScreen {
    UIViewController *child = [self childAt:CGRectMake(0, 0, 400, 400)];
    _root.view.hidden = YES;
    XCTAssertFalse(NRMA_IsControllerViewOnScreen(child));
}

- (void)testAControllerWithNoWindowIsNotOnScreen {
    UIViewController *detached = [[UIViewController alloc] init];
    (void)detached.view;
    XCTAssertFalse(NRMA_IsControllerViewOnScreen(detached));
}

#pragma mark - Classes that are never screens

// The logout confirmation in ExpensesTracker was reported as a 10-second visit named
// "UIAlertController". An alert interrupts a screen; it is not one.
- (void)testAlertControllerIsNotAScreen {
    XCTAssertTrue(NRMA_ShouldSkipViewName(@"UIAlertController"));
}

- (void)testAnAppControllerIsStillAScreen {
    XCTAssertFalse(NRMA_ShouldSkipViewName(@"CheckoutViewController"));
}

@end
