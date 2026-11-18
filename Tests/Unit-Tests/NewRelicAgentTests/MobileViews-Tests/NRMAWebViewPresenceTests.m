//
//  NRMAWebViewPresenceTests.m
//  NewRelicAgent
//
//  containsWebView / isFullScreenWebView on MobileView events: what counts as a visible web view, the
//  content area its coverage is measured against, and the accumulation across a visit that lets a web
//  view added or expanded after viewDidAppear: still count.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "NRMAWebViewPresence.h"
#import "NRMAMobileViewTracker.h"
#import "NRMAFlags.h"
#import "NewRelic.h"

@interface NRMAWebViewPresenceTests : XCTestCase
@end

@implementation NRMAWebViewPresenceTests {
    UIWindow *_window;
    UIViewController *_screen;
}

- (void)setUp {
    [super setUp];
    [NRMAWebViewPresence installWindowObservers];

    _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 400, 800)];
    // A hidden window hides everything in it, which would make every "not visible" case pass for the
    // wrong reason.
    _window.hidden = NO;
    _screen = [[UIViewController alloc] init];
    _window.rootViewController = _screen;
    _screen.view.frame = _window.bounds;
    [_screen.view layoutIfNeeded];
}

- (void)tearDown {
    // Any visit a failed test left open would keep the observer's fast path off for the rest.
    [NRMAWebViewPresence endVisitForController:_screen];
    _window.rootViewController = nil;
    _window.hidden = YES;
    _window = nil;
    _screen = nil;
    [super tearDown];
}

- (WKWebView *)webViewAt:(CGRect)frame in:(UIView *)parent {
    WKWebView *webView = [[WKWebView alloc] initWithFrame:frame configuration:[WKWebViewConfiguration new]];
    [parent addSubview:webView];
    return webView;
}

/// The screen's content area in its own view's coordinates. The bundle runs hosted, so a window's
/// root controller gets the device's real status-bar inset; geometry is laid out from this rather than
/// assumed.
- (CGRect)contentRect {
    return UIEdgeInsetsInsetRect(_screen.view.bounds, _screen.view.safeAreaInsets);
}

- (UIViewController *)childAt:(CGRect)frame of:(UIViewController *)parent {
    UIViewController *child = [[UIViewController alloc] init];
    [parent addChildViewController:child];
    child.view.frame = frame;
    [parent.view addSubview:child.view];
    [child didMoveToParentViewController:parent];
    return child;
}

- (NRMAWebViewPresence *)visitOf:(UIViewController *)controller {
    [NRMAWebViewPresence beginVisitForController:controller];
    return [NRMAWebViewPresence endVisitForController:controller];
}

#pragma mark - Native screens

- (void)testANativeScreenReportsNoWebView {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 800)];
    [_screen.view addSubview:label];

    NRMAWebViewPresence *presence = [self visitOf:_screen];

    XCTAssertFalse(presence.containsWebView);
    XCTAssertFalse(presence.isFullScreenWebView);
}

- (void)testAControllerWithNoVisitReportsNoWebView {
    [self webViewAt:_window.bounds in:_screen.view];

    NRMAWebViewPresence *presence = [NRMAWebViewPresence endVisitForController:_screen];

    XCTAssertFalse(presence.containsWebView);
    XCTAssertFalse(presence.isFullScreenWebView);
    XCTAssertFalse([NRMAWebViewPresence endVisitForController:nil].containsWebView);
}

#pragma mark - Full-screen web views

- (void)testAWebViewFillingTheScreenIsFullScreen {
    [self webViewAt:_window.bounds in:_screen.view];

    NRMAWebViewPresence *presence = [self visitOf:_screen];

    XCTAssertTrue(presence.containsWebView);
    XCTAssertTrue(presence.isFullScreenWebView);
}

// The web view starts below a 200 pt bar: under 80% of the view, but all of the content area.
// Measured against the view it would miss the threshold; against the content area it is the whole
// screen.
- (void)testAWebViewBelowABarIsMeasuredAgainstTheContentArea {
    _screen.additionalSafeAreaInsets = UIEdgeInsetsMake(200, 0, 0, 0);
    [_screen.view layoutIfNeeded];
    CGRect content = [self contentRect];
    XCTAssertLessThan(content.size.height / _screen.view.bounds.size.height, kNRMAFullScreenWebViewCoverage,
                      @"precondition: the web view is under 80%% of the whole view");

    [self webViewAt:content in:_screen.view];

    XCTAssertEqualWithAccuracy(NRMA_ContentAreaInWindow(_screen).size.height, content.size.height, 0.5);
    XCTAssertTrue([self visitOf:_screen].isFullScreenWebView);
}

// NRTestApp's WebViewController shape, inside a real navigation controller, on an iPad-sized
// landscape window.
- (void)testAWebViewUnderARealNavigationBarIsFullScreenInLandscapeIPad {
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 1366, 1024)];
    window.hidden = NO;
    UIViewController *web = [[UIViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:web];
    window.rootViewController = nav;
    [nav.view layoutIfNeeded];
    WKWebView *webView = [self webViewAt:CGRectZero in:web.view];
    webView.frame = UIEdgeInsetsInsetRect(web.view.bounds, web.view.safeAreaInsets);

    NRMAWebViewPresence *presence = [self visitOf:web];

    XCTAssertTrue(presence.containsWebView);
    XCTAssertTrue(presence.isFullScreenWebView);
    window.rootViewController = nil;
    window.hidden = YES;
}

#pragma mark - Embedded web content

- (void)testASmallBannerIsWebContentButNotFullScreen {
    [self webViewAt:CGRectMake(0, 600, 400, 200) in:_screen.view];

    NRMAWebViewPresence *presence = [self visitOf:_screen];

    XCTAssertTrue(presence.containsWebView);
    XCTAssertFalse(presence.isFullScreenWebView);
}

// Four quarter-screen web views cover the whole screen between them, but the threshold applies to one.
- (void)testSeveralSmallWebViewsDoNotAddUpToFullScreen {
    CGRect content = [self contentRect];
    CGFloat quarter = content.size.height / 4;
    for (NSInteger i = 0; i < 4; i++) {
        [self webViewAt:CGRectMake(0, content.origin.y + quarter * i, 400, quarter) in:_screen.view];
    }

    NRMAWebViewMeasurement measurement = NRMA_MeasureWebViews(_screen);
    XCTAssertTrue(measurement.containsWebView);
    XCTAssertEqualWithAccuracy(measurement.largestCoverage, 0.25, 0.001);
    XCTAssertFalse([self visitOf:_screen].isFullScreenWebView);
}

- (void)testTheThresholdIsEightyPercentOfTheContentArea {
    CGRect content = [self contentRect];
    CGRect frame = content;
    frame.size.height = floor(content.size.height * 0.79);
    WKWebView *webView = [self webViewAt:frame in:_screen.view];
    XCTAssertFalse([self visitOf:_screen].isFullScreenWebView, @"79%%");

    frame.size.height = ceil(content.size.height * 0.80);
    webView.frame = frame;
    XCTAssertTrue([self visitOf:_screen].isFullScreenWebView, @"80%%");
}

#pragma mark - Web content inside a child controller

- (void)testAParentEmbeddingAFullSizeWebChildIsFullScreen {
    UIViewController *child = [self childAt:CGRectMake(0, 0, 400, 720) of:_screen];
    [self webViewAt:child.view.bounds in:child.view];

    [NRMAWebViewPresence beginVisitForController:_screen];
    [NRMAWebViewPresence beginVisitForController:child];
    NRMAWebViewPresence *childPresence = [NRMAWebViewPresence endVisitForController:child];
    NRMAWebViewPresence *parentPresence = [NRMAWebViewPresence endVisitForController:_screen];

    XCTAssertTrue(parentPresence.containsWebView);
    XCTAssertTrue(parentPresence.isFullScreenWebView, @"90% of the parent's content area");
    XCTAssertTrue(childPresence.isFullScreenWebView);
    XCTAssertFalse(NRMA_IsTopLevelController(child));
}

// The parent shows web content, but only through a half-height child. The child's own event is
// measured against the child, which the web view fills.
- (void)testEachControllerIsMeasuredAgainstItsOwnContentArea {
    UIViewController *child = [self childAt:CGRectMake(0, 400, 400, 400) of:_screen];
    [self webViewAt:child.view.bounds in:child.view];

    NRMAWebViewPresence *parent = [self visitOf:_screen];
    NRMAWebViewPresence *own = [self visitOf:child];

    XCTAssertTrue(parent.containsWebView);
    XCTAssertFalse(parent.isFullScreenWebView);
    XCTAssertTrue(own.isFullScreenWebView);
}

#pragma mark - Changes during the visit

// Added after the visit opened: the window-move observer credits it, with no further sample taken.
- (void)testAWebViewAddedDuringTheVisitIsCounted {
    [NRMAWebViewPresence beginVisitForController:_screen];
    XCTAssertFalse(NRMA_MeasureWebViews(_screen).containsWebView, @"precondition: none at appear");

    WKWebView *webView = [self webViewAt:CGRectMake(0, 0, 400, 800) in:_screen.view];
    // Gone again before the visit ends; it was still on screen during it.
    [webView removeFromSuperview];

    NRMAWebViewPresence *presence = [NRMAWebViewPresence endVisitForController:_screen];
    XCTAssertTrue(presence.containsWebView);
    XCTAssertTrue(presence.isFullScreenWebView);
}

// The disappear sample (viewWillDisappear: in the tracker) sees the expanded size.
- (void)testAWebViewExpandedDuringTheVisitIsFullScreen {
    WKWebView *webView = [self webViewAt:CGRectMake(0, 600, 400, 200) in:_screen.view];
    [NRMAWebViewPresence beginVisitForController:_screen];

    webView.frame = _window.bounds;
    [NRMAWebViewPresence sampleController:_screen];
    webView.frame = CGRectMake(0, 600, 400, 200);

    XCTAssertTrue([NRMAWebViewPresence endVisitForController:_screen].isFullScreenWebView);
}

// Removing the expanded web view samples it on the way out of the window.
- (void)testAnExpandedWebViewIsSampledAsItLeavesTheWindow {
    WKWebView *webView = [self webViewAt:CGRectMake(0, 600, 400, 200) in:_screen.view];
    [NRMAWebViewPresence beginVisitForController:_screen];

    webView.frame = _window.bounds;
    [webView removeFromSuperview];

    XCTAssertTrue([NRMAWebViewPresence endVisitForController:_screen].isFullScreenWebView);
}

- (void)testNothingIsCreditedToAControllerWithNoVisitInProgress {
    [self webViewAt:_window.bounds in:_screen.view];
    [NRMAWebViewPresence sampleController:_screen];

    XCTAssertFalse([NRMAWebViewPresence endVisitForController:_screen].containsWebView);
}

// Two producers reporting one controller -- two .NRMobileView modifiers in one host -- share the
// accumulator; the first to end must not take it away from the second.
- (void)testNestedVisitsShareOneAccumulator {
    [NRMAWebViewPresence beginVisitForController:_screen];
    [NRMAWebViewPresence beginVisitForController:_screen];
    WKWebView *webView = [self webViewAt:_window.bounds in:_screen.view];

    XCTAssertTrue([NRMAWebViewPresence endVisitForController:_screen].containsWebView);
    [webView removeFromSuperview];
    XCTAssertTrue([NRMAWebViewPresence endVisitForController:_screen].containsWebView);
    XCTAssertFalse([NRMAWebViewPresence endVisitForController:_screen].containsWebView, @"detached");
}

#pragma mark - Web views that do not count

- (void)testAHiddenWebViewIsIgnored {
    [self webViewAt:_window.bounds in:_screen.view].hidden = YES;
    XCTAssertFalse([self visitOf:_screen].containsWebView);
}

- (void)testAWebViewInsideAHiddenContainerIsIgnored {
    UIView *container = [[UIView alloc] initWithFrame:_window.bounds];
    container.hidden = YES;
    [_screen.view addSubview:container];
    [self webViewAt:container.bounds in:container];

    XCTAssertFalse([self visitOf:_screen].containsWebView);
}

- (void)testATransparentWebViewIsIgnored {
    [self webViewAt:_window.bounds in:_screen.view].alpha = 0;
    XCTAssertFalse([self visitOf:_screen].containsWebView);
}

- (void)testAWebViewOutsideTheWindowIsIgnored {
    [self webViewAt:CGRectMake(400, 0, 400, 800) in:_screen.view];
    XCTAssertFalse([self visitOf:_screen].containsWebView);
}

// Scrolled out of a clipping scroll view: inside the window's bounds geometrically, but not visible.
- (void)testAWebViewClippedAwayByItsScrollViewIsIgnored {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    scroll.contentSize = CGSizeMake(400, 2000);
    [_screen.view addSubview:scroll];
    [self webViewAt:CGRectMake(0, 1000, 400, 300) in:scroll];

    XCTAssertFalse([self visitOf:_screen].containsWebView);

    scroll.contentOffset = CGPointMake(0, 900);
    XCTAssertTrue([self visitOf:_screen].containsWebView);
}

- (void)testAControllerNotInAWindowHasNoWebView {
    UIViewController *detached = [[UIViewController alloc] init];
    [self webViewAt:CGRectMake(0, 0, 400, 800) in:detached.view];

    XCTAssertFalse(NRMA_MeasureWebViews(detached).containsWebView);
    XCTAssertTrue(CGRectIsNull(NRMA_ContentAreaInWindow(detached)));
}

#pragma mark - References, flags, cost

- (void)testTheAgentKeepsNoReferenceToAWebView {
    __weak WKWebView *weakWebView = nil;
    @autoreleasepool {
        [NRMAWebViewPresence beginVisitForController:_screen];
        WKWebView *webView = [self webViewAt:_window.bounds in:_screen.view];
        weakWebView = webView;
        [NRMAWebViewPresence sampleController:_screen];
        [webView removeFromSuperview];
    }
    // WebKit itself lets go of a removed web view on a later run loop turn.
    for (NSInteger turn = 0; turn < 20 && weakWebView != nil; turn++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    XCTAssertNil(weakWebView);
    XCTAssertTrue([NRMAWebViewPresence endVisitForController:_screen].containsWebView);
}

- (void)testTheAgentKeepsNoReferenceToAControllerMidVisit {
    __weak UIViewController *weakController = nil;
    @autoreleasepool {
        UIViewController *controller = [[UIViewController alloc] init];
        weakController = controller;
        [self webViewAt:CGRectMake(0, 0, 100, 100) in:controller.view];
        [NRMAWebViewPresence beginVisitForController:controller];
    }
    XCTAssertNil(weakController);
}

// Detection is Mobile Views' own: with web view instrumentation off it still works, and installing it
// does not install that instrumentation's WKWebView initializer.
- (void)testDetectionIsIndependentOfWebViewInstrumentation {
    [NewRelic disableFeatures:NRFeatureFlag_WebViewInstrumentation];
    Method init = class_getInstanceMethod([WKWebView class], @selector(initWithFrame:configuration:));
    IMP before = method_getImplementation(init);

    [NRMAWebViewPresence installWindowObservers];
    [self webViewAt:_window.bounds in:_screen.view];

    XCTAssertTrue([self visitOf:_screen].isFullScreenWebView);
    XCTAssertEqual(method_getImplementation(init), before);
}

// A deep native hierarchy: what a visit's appear or disappear sample costs.
- (void)testMeasuringADeepHierarchyIsCheap {
    UIView *parent = _screen.view;
    for (NSInteger i = 0; i < 1000; i++) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, 800)];
        // Half nested, half siblings: deep and wide.
        [(i % 2 ? parent : _screen.view) addSubview:view];
        if (i % 2 == 0) { parent = view; }
    }
    [self webViewAt:CGRectMake(0, 0, 400, 100) in:parent];

    const NSInteger iterations = 200;
    CFTimeInterval start = CACurrentMediaTime();
    for (NSInteger i = 0; i < iterations; i++) {
        XCTAssertTrue(NRMA_MeasureWebViews(_screen).containsWebView);
    }
    double perSampleMs = (CACurrentMediaTime() - start) * 1000.0 / iterations;
    NSLog(@"NRMA_MeasureWebViews, 1000-view hierarchy: %.3f ms per sample", perSampleMs);
    // Loose: an unoptimized simulator build on a shared CI host. The budget on device is 1 ms a visit.
    XCTAssertLessThan(perSampleMs, 5.0);
}

@end
