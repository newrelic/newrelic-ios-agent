//
//  NRMAMobileViewTracker.h
//  NewRelicAgent
//
//  POC: MobileViews feature — automatic UIViewController lifecycle tracking.
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
 *   - (NSString *)nrMobileViewName { return @"Product Detail"; }
 *
 * Swift (no 'override' — there is no base implementation to override):
 *   @objc func nrMobileViewName() -> String { "Product Detail" }
 *
 * Return nil or empty string to use the default demangled class name.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@interface NRMAMobileViewTracker : NSObject

+ (instancetype)sharedInstance;

/**
 * Installs UIViewController swizzles. Call once during agent startup.
 * Safe to call multiple times — guarded by dispatch_once internally.
 */
- (void)start;

@end

NS_ASSUME_NONNULL_END
