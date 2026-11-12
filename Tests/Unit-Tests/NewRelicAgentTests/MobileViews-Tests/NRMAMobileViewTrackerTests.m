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

// A customer's own container: a plain UIViewController that embeds children.
@interface NRMATestDashboardContainer : UIViewController
@end
@implementation NRMATestDashboardContainer
@end

// A customer's navigation controller subclass -- the norm in real apps, not the exception.
@interface NRMATestAppNavigationController : UINavigationController
@end
@implementation NRMATestAppNavigationController
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

// WebKit attaches Screen Time's controllers inside every WKWebView. Observed in NRTestApp: each visit
// to its web view screen was followed by an "STWebpageController" visit that became the next screen's
// previousView.
- (void)testScreenTimeWebControllersAreNotScreens {
    XCTAssertTrue(NRMA_ShouldSkipViewName(@"STWebpageController"));
    XCTAssertTrue(NRMA_ShouldSkipViewName(@"STWebRemoteViewController"));
}

- (void)testAnAppControllerIsStillAScreen {
    XCTAssertFalse(NRMA_ShouldSkipViewName(@"CheckoutViewController"));
}

#pragma mark - isTopLevelView

- (UIViewController *)embed:(UIViewController *)child in:(UIViewController *)parent {
    [parent addChildViewController:child];
    [parent.view addSubview:child.view];
    [child didMoveToParentViewController:parent];
    return child;
}

- (void)testAPushedScreenIsTopLevel {
    UIViewController *root = [[UIViewController alloc] init];
    UIViewController *pushed = [[UIViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    [nav pushViewController:pushed animated:NO];

    XCTAssertTrue(NRMA_IsTopLevelController(root));
    XCTAssertTrue(NRMA_IsTopLevelController(pushed));
}

- (void)testATabRootIsTopLevel {
    UIViewController *first = [[UIViewController alloc] init];
    UIViewController *inStack = [[UIViewController alloc] init];
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[first, [[UINavigationController alloc] initWithRootViewController:inStack]];

    XCTAssertTrue(NRMA_IsTopLevelController(first));
    XCTAssertTrue(NRMA_IsTopLevelController(inStack));
}

- (void)testASplitViewColumnIsTopLevel {
    UIViewController *primary = [[UIViewController alloc] init];
    UIViewController *secondary = [[UIViewController alloc] init];
    UISplitViewController *split = [[UISplitViewController alloc] init];
    split.viewControllers = @[primary, secondary];

    XCTAssertTrue(NRMA_IsTopLevelController(primary));
    XCTAssertTrue(NRMA_IsTopLevelController(secondary));
}

// A presented controller has no parent; a presented navigation stack's root has only the stack.
- (void)testAModalRootIsTopLevel {
    XCTAssertTrue(NRMA_IsTopLevelController([[UIViewController alloc] init]));

    UIViewController *root = [[UIViewController alloc] init];
    (void)[[UINavigationController alloc] initWithRootViewController:root];
    XCTAssertTrue(NRMA_IsTopLevelController(root));
}

- (void)testAPageIsTopLevel {
    UIViewController *page = [[UIViewController alloc] init];
    UIPageViewController *pager = [[UIPageViewController alloc]
        initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                        options:nil];
    [pager setViewControllers:@[page] direction:UIPageViewControllerNavigationDirectionForward
                     animated:NO completion:nil];

    XCTAssertTrue(NRMA_IsTopLevelController(page));
}

- (void)testAChildEmbeddedWithAddChildIsNotTopLevel {
    UIViewController *card = [self embed:[[UIViewController alloc] init] in:_root];
    XCTAssertFalse(NRMA_IsTopLevelController(card));
}

- (void)testAChildOfACustomersContainerIsNotTopLevel {
    NRMATestDashboardContainer *container = [[NRMATestDashboardContainer alloc] init];
    UIViewController *card = [self embed:[[UIViewController alloc] init] in:container];
    UIViewController *nested = [self embed:[[UIViewController alloc] init] in:card];

    XCTAssertTrue(NRMA_IsTopLevelController(container));
    XCTAssertFalse(NRMA_IsTopLevelController(card));
    XCTAssertFalse(NRMA_IsTopLevelController(nested));
}

- (void)testAScreenInACustomersNavigationSubclassIsTopLevel {
    UIViewController *root = [[UIViewController alloc] init];
    (void)[[NRMATestAppNavigationController alloc] initWithRootViewController:root];
    XCTAssertTrue(NRMA_IsTopLevelController(root));
}

// ExpensesTracker's Home: a screen that embeds a UITabBarController and a side-menu drawer. The tabs
// are screens -- they sit in a tab container's slots -- while the drawer is part of Home.
- (void)testATabInsideAScreensEmbeddedTabBarIsTopLevelButItsDrawerIsNot {
    NRMATestDashboardContainer *home = [[NRMATestDashboardContainer alloc] init];
    (void)[[NRMATestAppNavigationController alloc] initWithRootViewController:home];
    UIViewController *dashboard = [[UIViewController alloc] init];
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[dashboard];
    [self embed:tabs in:home];
    UIViewController *sideMenu = [self embed:[[UIViewController alloc] init] in:home];

    XCTAssertTrue(NRMA_IsTopLevelController(home));
    XCTAssertTrue(NRMA_IsTopLevelController(dashboard));
    XCTAssertFalse(NRMA_IsTopLevelController(sideMenu));
}

@end
