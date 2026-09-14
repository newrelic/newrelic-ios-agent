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

/// Longest construction-to-appear interval still treated as a measurement rather than an artifact.
///
/// A load start is only trustworthy when the runtime built the screen *because* it was about to show
/// it. Every producer has a case where that is false -- SwiftUI builds every tab's content struct up
/// front to resolve tab items, UIKit loads a view whose `view` property was touched early, and a
/// manual `beginViewLoad` may never be followed by a `setCurrentView:`. All three then report the
/// interval since app launch as a screen load.
///
/// Above this, `loadTime` and the `timeToInitialDisplay` baseline are both withheld and the appear
/// event carries `loadTimeUnavailable` instead, so the omission is diagnosable in NRDB rather than
/// looking like the attribute was never implemented.
///
/// Chosen to separate "slow screen" from "constructed long before shown": a genuinely slow
/// synchronous load is at most a few seconds, while eager construction is tens of seconds or more.
/// Deliberately not tight -- a tight ceiling silently truncates the right tail of the baseline,
/// which is exactly the population worth looking at.
FOUNDATION_EXPORT const double kNRMAMaxPlausibleLoadMs;

@class NRMAViewTimingSnapshot;

@interface NRMAViewContext : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Clock

/// The clock every view timestamp must come from: monotonic seconds, unaffected by NTP steps or a
/// user changing the device clock.
///
/// Wall clock (`CFAbsoluteTimeGetCurrent`, `Date()`) is not acceptable for these measurements. A
/// backwards adjustment mid-load yields a negative interval, and because `millisecondsBetween:and:`
/// floors at 0 that surfaces as a *0 ms* load -- a fabricated perfect score, indistinguishable from
/// a real one and silently dragging every percentile computed over the baseline.
///
/// The values are only meaningful as differences within one process: the epoch is process-relative
/// and resets across launches. Nothing persists them (only view names and instance ids are written
/// through to disk), so that is safe.
///
/// Sleep is excluded, which is what the measurements want -- a screen that was visible when the
/// device slept should not report the sleep as time on screen.
+ (CFAbsoluteTime)monotonicNow;

#pragma mark - Automatic producers (UIKit swizzle / SwiftUI modifier)

/// Records that an automatically-tracked view `name` (uniquely identified by `instanceId`, first
/// visible at `appearTime`) is now the current view. The previously-current view becomes the
/// previous view — the referrer for the new view and for breadcrumbs recorded while it is visible.
///
/// Timestamps are monotonic seconds from `+monotonicNow`.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime;

/// As above, recording which producer saw the appearance so a synthesized re-appearance can report
/// the same `uiPlatform` the original event did.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime
                platform:(nullable NSString *)platform;

/// As above, and carries the instant the runtime began building this screen. Prefer this form.
///
/// `loadStartTime` is the shared origin for *both* the agent's `timeToInitialDisplay` baseline and
/// every customer `markViewTiming:` on this view. Anchoring them together is what makes
/// `timeToFullDisplay - timeToInitialDisplay` a valid subtraction: the two series measure from one
/// instant, so the difference is the interval during which the screen looked finished but was not.
/// Anchoring marks at `appearTime` instead makes them *adjacent* to the baseline rather than
/// enclosing it, and the subtraction changes sign depending on the screen.
///
/// Pass nil when the producer cannot vouch for a construction start -- nothing was built (a
/// re-appearance, a tab selection), the agent started mid-construction, or the interval exceeded
/// `kNRMAMaxPlausibleLoadMs`. Then no baseline row is emitted and marks fall back to `appearTime` --
/// which also means such a view has no baseline for a mark to be wrongly subtracted from. Whether a
/// given visit had a construction start is recoverable from its `MobileView` appear event, which
/// carries `loadTime` exactly when one was vouched for.
- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime
           loadStartTime:(nullable NSNumber *)loadStartTime
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

/// Records that construction of the *next* manually-set view starts now, giving manual views the
/// construction-start origin the automatic producers get from `viewDidLoad` / modifier init.
///
/// Manual views have no lifecycle the agent can observe: `setCurrentView:` is called at the moment
/// the screen is already showing, so load start and appear are the same instant and a baseline
/// derived from them would be identically zero. Rather than emit a zero -- which is a real value in
/// every percentile and indistinguishable from an instant load -- the baseline is simply absent for
/// manual views unless the customer marks the start with this method.
///
/// Consumed by the next `setCurrentManualView:attributes:`, and only if that call arrives within
/// `kNRMAMaxPlausibleLoadMs`; a begin with no matching set goes stale rather than attaching itself
/// to whatever screen appears next. Calling it again before a set replaces the pending start.
- (void)beginManualViewLoad;

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

/// Merges `referrerAttributes` into `attributes`, agent-owned referrer keys winning over any
/// caller-supplied attribute of the same name. Returns `attributes` unchanged (nil stays nil, never
/// promoted to an empty dictionary) unless at least one Mobile Views flag is enabled and a view is
/// currently set. Shared by every non-view producer §5.5 requires the referrer plumbing for:
/// breadcrumbs, MobileRequest, MobileRequestError, and Handled Exceptions.
+ (nullable NSDictionary<NSString *, id> *)mergeReferrerAttributesInto:(nullable NSDictionary<NSString *, id> *)attributes;

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

/// Immutable copy of the current view, both of its timing origins (load start and appear), and its
/// referrer, for MobileViewTiming.
///
/// Exists so timing never emits while holding this class's non-recursive os_unfair_lock: callers
/// take a snapshot, the lock is released here, and only then is an event recorded.
- (NRMAViewTimingSnapshot *)snapshotForTiming;

/// Single seconds → milliseconds conversion, floored at 0. All view timing (loadTime, timeVisible)
/// runs through here so the unit cannot drift between producers. Both arguments must come from
/// `+monotonicNow`; mixing a wall-clock value in is what the flooring would hide.
+ (double)millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end;

@end

NS_ASSUME_NONNULL_END
