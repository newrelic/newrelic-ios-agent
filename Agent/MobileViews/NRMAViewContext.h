//
//  NRMAViewContext.h
//  NewRelicAgent
//
//  Thread-safe source of truth for the currently-visible view and the one before it (the
//  "referrer"). All view producers funnel their transitions through here so breadcrumbs and
//  MobileView events can be stamped with a consistent currentView / previousView, regardless
//  of which producer is active:
//
//    - Automatic UIViewController swizzling  (NRMAMobileViewTracker, gated by AutomaticViews)
//    - Automatic SwiftUI .NRMobileView       (NRViewModifier, gated by AutomaticViews)
//    - Manual +[NewRelic setCurrentView:]    (gated by ManualViews)
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAViewContext : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Automatic producers (UIKit swizzle / SwiftUI modifier)

/// Records that an automatically-tracked view `name` (uniquely identified by `instanceId`, first
/// visible at `appearTime`) is now the current view. The previously-current view becomes the
/// previous view — the referrer for the new view and for breadcrumbs recorded while it is visible.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime;

#pragma mark - Manual producer (+[NewRelic setCurrentView:attributes:])

/// Sets the current view by name (browser route-change / SPA model). If a manual view is already
/// current, its MobileView `appeared:NO` event is emitted first (with timeVisible). Then `name`
/// becomes current and its MobileView `appeared:YES` event is emitted (stamped with previousView).
/// Auto-tracked views that happen to be current are left for their own viewDidDisappear to close.
- (void)setCurrentManualView:(NSString *)name attributes:(nullable NSDictionary<NSString *, id> *)attributes;

/// If the current view was set manually, emits its `appeared:NO` MobileView event (with timeVisible)
/// and clears it. Called on app background so the last manual view's duration is not lost.
- (void)flushCurrentManualViewOnBackground;

#pragma mark - Referrer accessors

/// Attributes for breadcrumbs and other non-view events: currentView, previousView,
/// previousViewInstanceId (only keys with values are included). Empty if no view is set.
- (NSDictionary<NSString *, id> *)referrerAttributes;

/// Attributes for MobileView events, which already carry the current view as viewName:
/// previousView, previousViewInstanceId (only keys with values are included).
- (NSDictionary<NSString *, id> *)previousViewAttributes;

#pragma mark - Timing

/// Single seconds → milliseconds conversion, floored at 0. All view timing (loadTime, timeVisible)
/// runs through here so the unit cannot drift between producers.
+ (double)millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end;

@end

NS_ASSUME_NONNULL_END
