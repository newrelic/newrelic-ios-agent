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
 *   restarted       (NSNumber/BOOL) — NO on first appearance, YES on subsequent appearances
 *   loadTime        (NSNumber/double, seconds) — viewDidLoad → viewDidAppear
 *   timeVisible     (NSNumber/double, seconds) — viewDidAppear → viewDidDisappear
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
 *   - empty string ""  → falls back to the demangled class name (legacy).
 *   - nil              → view is IGNORED entirely; no MobileView events emitted.
 *
 * ─── Custom attributes ───────────────────────────────────────────────────────
 *
 * Optionally implement nrMobileViewAttributes to attach extra attributes to every
 * MobileView event emitted for the view. Reserved keys (viewClass, viewName,
 * viewInstanceId, restarted, loadTime, timeVisible, appeared, uiPlatform,
 * agentName) cannot be overridden.
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
 * Records a view's load span as a segment on the interaction (activity trace) currently covering
 * it, so the screen shows up as a `MobileView/<viewName>` row in that interaction's breakdown.
 * The swizzled lifecycle rows can't say which screen they belong to — the method profiler traces
 * the class it swizzles, so every one of them reads `UIViewController/viewDidLoad`.
 *
 * `loadTime` and `appearTime` are CFAbsoluteTime, the domain both producers already capture in:
 * viewDidLoad → viewDidAppear for UIKit, modifier creation → onAppear for SwiftUI.
 *
 * A no-op unless MobileViews collection is enabled, an interaction is running, and the span is
 * positive. A `loadTime` of 0 means the load was never observed — a view reappearing without
 * reloading — rather than a load that took no time.
 */
+ (void)recordLoadSegmentForViewNamed:(NSString *)viewName
                             loadTime:(CFAbsoluteTime)loadTime
                           appearTime:(CFAbsoluteTime)appearTime;

@end

NS_ASSUME_NONNULL_END
