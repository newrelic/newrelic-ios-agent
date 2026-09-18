//
//  NRMAMobileViewTracker.h
//  NewRelicAgent
//
//  MobileViews: automatic UIViewController lifecycle tracking.
//  Emits "MobileView" custom events with timing and identity attributes.
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * NRMAMobileViewTracker swizzles UIViewController lifecycle methods to automatically
 * record MobileView events.
 *
 * Attributes emitted on each MobileView event:
 *   viewClass       (NSString) — Fully-qualified demangled class name, e.g. "MyApp.ProductViewController"
 *   viewName        (NSString) — Simple display name, e.g. "ProductViewController"; customisable (see below)
 *   viewInstanceId  (NSString) — UUID unique to this single visible lifetime of the view
 *   loadTime        (NSNumber/double, milliseconds) — viewDidLoad → viewDidAppear
 *   timeVisible     (NSNumber/double, milliseconds) — viewDidAppear → viewDidDisappear
 *
 * ─── Customising viewName ────────────────────────────────────────────────────
 *
 * No protocol adoption or header import required. Just implement nrMobileViewName
 * on any UIViewController subclass and it will be picked up automatically.
 *
 * Objective-C:
 *   - (nullable NSString *)nrMobileViewName { return @"Product Detail"; }
 *
 * Swift (no 'override' — there is no base implementation to override):
 *   @objc func nrMobileViewName() -> String? { "Product Detail" }
 *
 * Return values:
 *   - non-empty string → used as viewName.
 *   - empty string ""  → falls back to the demangled class name.
 *   - nil              → falls back to the demangled class name.
 *
 * The hook renames a view; it cannot suppress one. Returning nil used to mean "ignore this view
 * entirely", which made the natural Swift shape -- compute a name, return nil when there is nothing
 * better -- silently drop the screen. Whether views are collected at all is decided by the
 * NRFeatureFlag_AutomaticMobileViews flag.
 *
 * ─── Custom attributes ───────────────────────────────────────────────────────
 *
 * Optionally implement nrMobileViewAttributes to attach extra attributes to every
 * MobileView event emitted for the view. Reserved keys (viewClass, viewName,
 * viewInstanceId, loadTime, timeVisible, previousView, uiFramework)
 * cannot be overridden.
 *
 * Objective-C:
 *   - (nullable NSDictionary<NSString *, id> *)nrMobileViewAttributes {
 *       return @{ @"productId": @42, @"section": @"detail" };
 *   }
 *
 * Swift:
 *   @objc func nrMobileViewAttributes() -> [String: Any]? {
 *       ["productId": 42, "section": "detail"]
 *   }
 * ─────────────────────────────────────────────────────────────────────────────
 */
@interface NRMAMobileViewTracker : NSObject

FOUNDATION_EXPORT BOOL NRMA_ShouldSkipViewName(NSString *viewName);

+ (instancetype)sharedInstance;

/**
 * Installs UIViewController swizzles. Call once during agent startup.
 * Safe to call multiple times — guarded by dispatch_once internally.
 */
- (void)start;

/**
 * Ends the visit of every view that is currently on screen, recording one MobileView event each.
 *
 * Call when the app is fully backgrounded. A MobileView event describes a completed visit, and no
 * UIViewController callback marks that moment: viewDidDisappear: does not fire when an app is
 * backgrounded, so without this the screen the user was on when they left the app -- the last
 * screen of most sessions -- reports nothing at all.
 *
 * `timeVisible` on these events therefore ends at backgrounding rather than at a navigation. The
 * event is otherwise ordinary and carries no marker saying so.
 *
 * Pair with -reopenOpenVisitsOnForeground, or those screens stay closed for the rest of the session.
 */
- (void)flushOpenVisitsOnBackground;

/**
 * Starts a new visit for every view still on screen, after -flushOpenVisitsOnBackground closed
 * theirs.
 *
 * Call when the app is foregrounded. Foregrounding fires no per-controller appearance callback --
 * UIKit never took the screen away -- so a visit closed at background would otherwise never
 * re-open: the user's time on that screen after returning would belong to no visit, and the shared
 * view context's visible stack would keep a hole where the screen still on the display used to be.
 *
 * Each re-opened visit gets a fresh `viewInstanceId` and no `loadTime`: nothing was rebuilt, the app
 * was resumed. One screen either side of a background therefore reports two visits, which is the
 * cost of both halves being measured.
 */
- (void)reopenOpenVisitsOnForeground;

@end

NS_ASSUME_NONNULL_END
