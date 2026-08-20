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

/// The join key between a MobileView event and the interaction (activity trace) event that covers
/// it. Exported so both producers use one definition and the two sides cannot drift apart.
FOUNDATION_EXPORT NSString * const kNRMAAttributeInteractionId;
/// Display name of that interaction, carried on MobileView events.
FOUNDATION_EXPORT NSString * const kNRMAAttributeInteractionName;

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

#pragma mark - Interaction correlation

/// Publishes the currently-running interaction (activity trace) so MobileView events emitted while
/// it runs can carry its identity. Pass nil/nil to clear when the interaction completes, so a view
/// event can never carry the id of a finished interaction.
///
/// Publishing a *different* id also discards any latched interaction→view binding (see
/// -viewCorrelationAttributes). Re-publishing the same id does not, so the second publish that
/// -startTracingWithName: makes once the real interaction name is known preserves an existing latch.
- (void)setCurrentInteractionId:(nullable NSString *)interactionId
                           name:(nullable NSString *)name;

/// Clears the published interaction only if `interactionId` is the one currently published.
///
/// This slot holds a single interaction, but NRMATraceController can now have several running at
/// once. When one completes it must not clear a sibling's identity: an unconditional clear would
/// strip interactionId from every MobileView event emitted after whichever interaction happened to
/// finish first, even though another is still open. A no-op when the ids do not match.
- (void)clearCurrentInteractionIdIfEqualTo:(nullable NSString *)interactionId;

/// Attributes for MobileView events: interactionId, interactionName (only keys with values).
/// Empty when no interaction is running.
- (NSDictionary<NSString *, id> *)interactionAttributes;

/// Attributes for the interaction event: viewName, viewInstanceId, previousView (only keys with
/// values). Deliberately uses the MobileView event's key names so the two event types join on
/// identically-named attributes — unlike -referrerAttributes, which emits the current view under
/// the breadcrumb key `currentView`.
///
/// Reports the view *latched* when the running interaction's screen became current — the first view
/// to become current after the interaction started — rather than whichever view happens to be
/// current at completion. An interaction can outlive the screen it describes (quiescence defaults to
/// 30s, and a custom interaction is never superseded), so a completion-time read would misattribute
/// it. Falls back to the current view when no transition occurred while the interaction was open.
- (NSDictionary<NSString *, id> *)viewCorrelationAttributes;

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
