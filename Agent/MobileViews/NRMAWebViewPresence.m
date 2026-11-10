//
//  NRMAWebViewPresence.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAWebViewPresence.h"
#import <objc/runtime.h>
#import <stdatomic.h>
#import "NRMAMethodSwizzling.h"

#if !TARGET_OS_WATCH

const CGFloat kNRMAFullScreenWebViewCoverage = 0.8;

// UIKit's own threshold: a view at or below this alpha does not receive touches, and is treated here
// as not shown. A web view fading in is picked up by a later sample.
static const CGFloat kNRMAMinimumVisibleAlpha = 0.01;

static const char kNRWebViewPresenceKey;

// Accumulators alive. Lets the window-move observer return immediately while nothing is being
// tracked. Counted by the accumulator's own lifetime rather than by begin/end, so a controller that is
// deallocated mid-visit -- no viewDidDisappear: ever comes -- does not leave the count raised forever.
// Atomic because that last release can happen off the main thread; everything else here is main-only.
static atomic_long sLiveAccumulators = 0;

@interface NRMAWebViewPresence ()
@property (nonatomic) BOOL containsWebView;
@property (nonatomic) CGFloat largestCoverage;
@property (nonatomic) NSInteger openCount;
/// Attached to a controller, as opposed to a snapshot handed back by -endVisitForController:.
@property (nonatomic) BOOL counted;
@end

/// Looked up rather than linked: the agent does not link WebKit, and on tvOS there is no WKWebView.
static Class NRMA_WKWebViewClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = objc_getClass("WKWebView"); });
    return cls;
}

static CGFloat NRMA_Area(CGRect rect) {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) { return 0; }
    return rect.size.width * rect.size.height;
}

/*
 * The part of `view` a user can see, in window coordinates, or CGRectNull when there is none: it or
 * a view above it is hidden or transparent, it is not in a window, or every pixel of it is clipped
 * away -- by an ancestor that clips to bounds (a scroll view scrolled past it), or by the window edge.
 *
 * Walks up rather than being carried down the traversal, because web views are rare and the walk is
 * only paid for each one found.
 */
static CGRect NRMA_VisibleRectInWindow(UIView *view) {
    UIWindow *window = view.window;
    if (window == nil) { return CGRectNull; }

    CGRect visible = [view convertRect:view.bounds toView:nil];
    for (UIView *node = view; node != nil; node = node.superview) {
        if (node.isHidden || node.alpha <= kNRMAMinimumVisibleAlpha) { return CGRectNull; }
        if (node != view && node.clipsToBounds) {
            visible = CGRectIntersection(visible, [node convertRect:node.bounds toView:nil]);
        }
        if (NRMA_Area(visible) == 0) { return CGRectNull; }
    }
    visible = CGRectIntersection(visible, window.bounds);
    return NRMA_Area(visible) > 0 ? visible : CGRectNull;
}

CGRect NRMA_ContentAreaInWindow(UIViewController *controller) {
    UIView *view = controller.viewIfLoaded;
    UIWindow *window = view.window;
    if (window == nil) { return CGRectNull; }

    CGRect content = UIEdgeInsetsInsetRect(view.bounds, view.safeAreaInsets);
    content = [view convertRect:content toView:nil];
    content = CGRectIntersection(content, window.bounds);
    return NRMA_Area(content) > 0 ? content : CGRectNull;
}

/// Share of `content` that `visible` covers, 0...1.
static CGFloat NRMA_Coverage(CGRect visible, CGRect content) {
    CGFloat contentArea = NRMA_Area(content);
    if (contentArea == 0) { return 0; }
    return MIN(1.0, NRMA_Area(CGRectIntersection(visible, content)) / contentArea);
}

/*
 * Depth-first over `view`'s subtree. A hidden or transparent subtree is skipped whole, and a web view
 * is not descended into: its own scroll and tile views are thousands of nodes deep and none of them
 * can be another web view the user would recognise as separate content.
 */
static void NRMA_CollectWebViews(UIView *view, Class webViewClass, CGRect content,
                                 NRMAWebViewMeasurement *measurement) {
    if (view.isHidden || view.alpha <= kNRMAMinimumVisibleAlpha) { return; }

    if ([view isKindOfClass:webViewClass]) {
        CGRect visible = NRMA_VisibleRectInWindow(view);
        if (CGRectIsNull(visible)) { return; }
        measurement->containsWebView = YES;
        measurement->largestCoverage = MAX(measurement->largestCoverage, NRMA_Coverage(visible, content));
        return;
    }

    for (UIView *subview in view.subviews) {
        NRMA_CollectWebViews(subview, webViewClass, content, measurement);
    }
}

NRMAWebViewMeasurement NRMA_MeasureWebViews(UIViewController *controller) {
    NRMAWebViewMeasurement measurement = { NO, 0 };
    Class webViewClass = NRMA_WKWebViewClass();
    UIView *root = controller.viewIfLoaded;
    if (webViewClass == Nil || root.window == nil) { return measurement; }

    NRMA_CollectWebViews(root, webViewClass, NRMA_ContentAreaInWindow(controller), &measurement);
    return measurement;
}

#pragma mark - WKWebView window moves

static void (*orig_willMoveToWindow)(id, SEL, UIWindow *);
static void (*orig_didMoveToWindow)(id, SEL);

/// The controller whose root view is `view`, if any.
static UIViewController *NRMA_ControllerOwningView(UIView *view) {
    UIResponder *next = view.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).viewIfLoaded == view) {
        return (UIViewController *)next;
    }
    return nil;
}

/*
 * Credits one web view to every controller above it with a visit in progress -- an embedded child and
 * the screen that embeds it alike -- each measured against its own content area.
 */
static void NRMA_NoteWebView(UIView *webView) {
    if (atomic_load(&sLiveAccumulators) == 0 || ![NSThread isMainThread]) { return; }

    CGRect visible = NRMA_VisibleRectInWindow(webView);
    if (CGRectIsNull(visible)) { return; }

    for (UIView *node = webView; node != nil; node = node.superview) {
        UIViewController *owner = NRMA_ControllerOwningView(node);
        if (owner == nil) { continue; }
        NRMAWebViewPresence *presence = objc_getAssociatedObject(owner, &kNRWebViewPresenceKey);
        if (presence == nil) { continue; }
        presence.containsWebView = YES;
        presence.largestCoverage = MAX(presence.largestCoverage,
                                       NRMA_Coverage(visible, NRMA_ContentAreaInWindow(owner)));
    }
}

// Sampled before the move, while the web view is still where the user saw it.
static void NRMA_WebView_willMoveToWindow(UIView *self, SEL _cmd, UIWindow *newWindow) {
    if (newWindow == nil && self.window != nil) { NRMA_NoteWebView(self); }
    if (orig_willMoveToWindow) { orig_willMoveToWindow(self, _cmd, newWindow); }
}

static void NRMA_WebView_didMoveToWindow(UIView *self, SEL _cmd) {
    if (orig_didMoveToWindow) { orig_didMoveToWindow(self, _cmd); }
    if (self.window != nil) { NRMA_NoteWebView(self); }
}

@implementation NRMAWebViewPresence

- (void)dealloc {
    if (_counted) { atomic_fetch_sub(&sLiveAccumulators, 1); }
}

- (BOOL)isFullScreenWebView {
    return self.containsWebView && self.largestCoverage >= kNRMAFullScreenWebViewCoverage;
}

- (void)addMeasurement:(NRMAWebViewMeasurement)measurement {
    if (!measurement.containsWebView) { return; }
    self.containsWebView = YES;
    self.largestCoverage = MAX(self.largestCoverage, measurement.largestCoverage);
}

+ (void)installWindowObservers {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class webViewClass = NRMA_WKWebViewClass();
        if (webViewClass == Nil) { return; }
        // Replaced on WKWebView itself, so the observer never runs for any other view. Where WKWebView
        // does not override a selector, the stored original is UIView's and is called the same way.
        orig_willMoveToWindow = (void (*)(id, SEL, UIWindow *))
            NRMAReplaceInstanceMethod(webViewClass, @selector(willMoveToWindow:),
                                      (IMP)NRMA_WebView_willMoveToWindow);
        orig_didMoveToWindow = (void (*)(id, SEL))
            NRMAReplaceInstanceMethod(webViewClass, @selector(didMoveToWindow),
                                      (IMP)NRMA_WebView_didMoveToWindow);
    });
}

+ (void)beginVisitForController:(UIViewController *)controller {
    NRMAWebViewPresence *presence = objc_getAssociatedObject(controller, &kNRWebViewPresenceKey);
    if (presence == nil) {
        presence = [NRMAWebViewPresence new];
        presence.counted = YES;
        atomic_fetch_add(&sLiveAccumulators, 1);
        objc_setAssociatedObject(controller, &kNRWebViewPresenceKey, presence,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    presence.openCount++;
    [presence addMeasurement:NRMA_MeasureWebViews(controller)];
}

+ (void)sampleController:(UIViewController *)controller {
    // Called from every controller's viewWillDisappear:. The early return is what keeps that cheap: a
    // message to nil still evaluates its arguments, so the traversal would run regardless.
    NRMAWebViewPresence *presence = objc_getAssociatedObject(controller, &kNRWebViewPresenceKey);
    if (presence == nil) { return; }
    [presence addMeasurement:NRMA_MeasureWebViews(controller)];
}

+ (NRMAWebViewPresence *)endVisitForController:(UIViewController *)controller {
    NRMAWebViewPresence *presence = controller
        ? objc_getAssociatedObject(controller, &kNRWebViewPresenceKey)
        : nil;
    if (presence == nil) { return [NRMAWebViewPresence new]; }

    [presence addMeasurement:NRMA_MeasureWebViews(controller)];

    presence.openCount--;
    if (presence.openCount > 0) {
        // Another producer's visit of this controller is still open: report a copy, keep accumulating.
        NRMAWebViewPresence *snapshot = [NRMAWebViewPresence new];
        snapshot.containsWebView = presence.containsWebView;
        snapshot.largestCoverage = presence.largestCoverage;
        return snapshot;
    }
    objc_setAssociatedObject(controller, &kNRWebViewPresenceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return presence;
}

@end

#endif
