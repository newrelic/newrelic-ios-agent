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

/// Marks a MobileView appear event the agent synthesized because a screen became visible again
/// when the view covering it went away, rather than because a producer observed an appearance.
FOUNDATION_EXPORT NSString * const kNRMAAttributeReappeared;

/// Shortest visible lifetime treated as a real appearance; below it, an appear/disappear pair is
/// construction churn. Exported so the SwiftUI producer flags the same threshold the context uses to
/// suppress synthesis -- two copies of this number would drift.
FOUNDATION_EXPORT const double kNRMAMinDwellMs;

@class NRMAViewTimingSnapshot;

@interface NRMAViewContext : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Automatic producers (UIKit swizzle / SwiftUI modifier)

/// Records that an automatically-tracked view `name` (uniquely identified by `instanceId`, first
/// visible at `appearTime`) is now the current view. The previously-current view becomes the
/// previous view — the referrer for the new view and for breadcrumbs recorded while it is visible.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime;

/// As above, recording which producer saw the appearance so a synthesized re-appearance can report
/// the same `uiPlatform` the original event did. Prefer this over the three-argument form.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime
                platform:(nullable NSString *)platform;

/// Records that an automatically-tracked view instance is no longer visible, and synthesizes a
/// MobileView appear event for whatever it was covering.
///
/// SwiftUI is the reason this exists. `onDisappear` fires when a NavigationStack pushes past a
/// view, but popping back to that view does *not* fire its `onAppear` again -- the root was never
/// torn down -- so nothing tells the agent the screen is visible again. Without this, the next
/// screen to appear reports a dismissed sheet as its `previousView`. UIKit does not have the
/// problem (`viewDidAppear:` fires on pop) and is unaffected: a real appearance always supersedes
/// a synthesized one.
///
/// `instanceId` identifies which visible lifetime ended, and it is removed from wherever it sits in
/// the stack rather than only from the top. That matters because SwiftUI fires the *incoming*
/// view's `onAppear` before the *outgoing* view's `onDisappear`, so by the time a push is reported
/// the departing view is already buried; and because a pop delivers its disappearances batched and
/// out of order. Only a removal that actually changes the top of the stack synthesizes an event.
- (void)viewDidDisappearNamed:(NSString *)name instanceId:(NSString *)instanceId;

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

/// Attributes for breadcrumbs and other non-view events: currentView, currentViewInstanceId,
/// previousView, previousViewInstanceId (only keys with values are included). Empty if no view is
/// set.
- (NSDictionary<NSString *, id> *)referrerAttributes;

/// Attributes for MobileView events, which already carry the current view as viewName:
/// previousView, previousViewInstanceId (only keys with values are included).
- (NSDictionary<NSString *, id> *)previousViewAttributes;

#pragma mark - Crash-time referrer recovery

/// `referrerAttributes` as of the most recent view transition, read back from disk. Meant for a
/// crash report processed on next launch: the crashed session's in-memory NRMAViewContext state is
/// gone, but this file survives because every transition writes through to it. Nil if nothing was
/// ever persisted (e.g. the app crashed before any view appeared, or the file was already
/// consumed). Read this before calling +clearPersistedReferrerAttributes.
+ (nullable NSDictionary<NSString *, NSString *> *)persistedReferrerAttributes;

/// Deletes whatever +persistedReferrerAttributes would return. Call once at startup -- after a
/// pending crash has had a chance to read it, if there was one -- so a session that exits cleanly
/// never leaves behind a view that a crash several sessions later would be wrongly attributed to.
+ (void)clearPersistedReferrerAttributes;

#pragma mark - Timing

/// Immutable copy of the current view, its appear time, and its referrer, for MobileViewTiming.
///
/// Exists so timing never emits while holding this class's non-recursive os_unfair_lock: callers
/// take a snapshot, the lock is released here, and only then is an event recorded.
- (NRMAViewTimingSnapshot *)snapshotForTiming;

/// Single seconds → milliseconds conversion, floored at 0. All view timing (loadTime, timeVisible)
/// runs through here so the unit cannot drift between producers.
+ (double)millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end;

@end

NS_ASSUME_NONNULL_END
