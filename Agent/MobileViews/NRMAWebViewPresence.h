//
//  NRMAWebViewPresence.h
//  NewRelicAgent
//
//  MobileViews: whether a screen shows web content, for the containsWebView / isFullScreenWebView
//  attributes on its MobileView event.
//
//  A screen's loadTime and timeVisible mean something different when its content is a web page: the
//  page loads after viewDidAppear:, so a "fast" native load can be a blank frame. These attributes let
//  a query separate native screens, native screens that embed some web content, and web pages in a
//  native frame.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !TARGET_OS_WATCH

/// Share of a controller's content area one web view must cover for the screen to count as a web page
/// in a native frame. Applies to a single web view: several small ones never add up to a full screen.
FOUNDATION_EXPORT const CGFloat kNRMAFullScreenWebViewCoverage;

/// One look at a controller's view tree.
typedef struct {
    /// A visible WKWebView is somewhere in the tree, including inside embedded child controllers.
    BOOL containsWebView;
    /// The largest share, 0...1, of the controller's content area that any *one* of those web views
    /// covers. 0 when there is none.
    CGFloat largestCoverage;
} NRMAWebViewMeasurement;

/// Measures `controller`'s view tree now. Nothing is found for a controller whose view is not in a
/// window.
///
/// Only an in-process WKWebView (or subclass) counts. A web view is ignored when it, or any view
/// above it, is hidden or effectively transparent, or when nothing of it is visible in the window
/// after clipping. Out-of-process web content -- SFSafariViewController, ASWebAuthenticationSession
/// -- has no WKWebView in the app's view tree, and the deprecated UIWebView is not a WKWebView.
FOUNDATION_EXPORT NRMAWebViewMeasurement NRMA_MeasureWebViews(UIViewController *controller);

/// The part of `controller`'s view a user can read content in, in window coordinates: its visible
/// bounds minus its safe area. The safe area is what removes navigation, tab and tool bars a
/// container lays over the view, along with the status bar and home indicator, which is why coverage
/// measured against it holds on iPhone, on iPad and in landscape alike. CGRectNull when the view is
/// not in a window.
FOUNDATION_EXPORT CGRect NRMA_ContentAreaInWindow(UIViewController *controller);

/**
 * What one visit's view tree showed of web content, accumulated across the visit.
 *
 * A MobileView event is written when the visit ends, so the answer does not have to be decided at
 * appear time: a web view added later (lazy loading, a SwiftUI state change) or expanded later still
 * counts. Each attribute is true when it was true at any sample taken during the visit. Samples are
 * taken only at these moments, all on the main thread:
 *
 *   - the visit opening (viewDidAppear:, or a foreground re-open),
 *   - viewWillDisappear: -- by viewDidDisappear: the view has usually left the window,
 *   - the visit closing, if the view is still in a window (a background flush),
 *   - a WKWebView moving into or out of a window under the controller's view.
 *
 * There is no sampling on layout. A web view that expands to full screen and shrinks back between two
 * of those moments is reported by the size it had at them.
 *
 * Nothing here holds a strong reference to a web view or a controller: the accumulator is an
 * associated object on the controller, and a sample keeps only numbers.
 */
@interface NRMAWebViewPresence : NSObject

@property (nonatomic, readonly) BOOL containsWebView;
/// Implies containsWebView.
@property (nonatomic, readonly) BOOL isFullScreenWebView;

/// Installs the WKWebView window-move observers. Idempotent, and a no-op where WebKit is not loaded
/// (tvOS, or an app that does not link it).
///
/// Independent of NRFeatureFlag_WebViewInstrumentation: this adds no navigation delegate, network
/// or supportability instrumentation, and installing it does not enable any.
+ (void)installWindowObservers;

/// Starts accumulating for a visit of `controller` and takes the first sample. Calls nest: two
/// producers reporting the same controller share one accumulator, and it is dropped by the last
/// -endVisitForController:.
+ (void)beginVisitForController:(UIViewController *)controller;

/// Adds a sample for a controller with a visit in progress; a no-op otherwise.
+ (void)sampleController:(UIViewController *)controller;

/// Takes a last sample if the view is still in a window and returns what the visit showed. Never
/// nil: a controller with no visit in progress -- or nil -- reports no web content.
+ (NRMAWebViewPresence *)endVisitForController:(nullable UIViewController *)controller;

@end

#endif

NS_ASSUME_NONNULL_END
