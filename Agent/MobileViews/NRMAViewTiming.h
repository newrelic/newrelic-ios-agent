//
//  NRMAViewTiming.h
//  NewRelicAgent
//
//  MobileViewTiming: timings that are only knowable *after* a view has appeared.
//
//  The MobileView appear event carries loadTime, but loadTime is fixed at viewDidAppear — so a
//  screen that renders a spinner in 80ms and real content in 900ms reports 80ms. Time to Full
//  Display and Time to Interactive cannot ride that event at all, because they are not known when
//  it is emitted. This type streams them as separate "MobileViewTiming" events instead, modelled on
//  browser's PageViewTiming: one event per timing, sent as soon as its value is known.
//
//  Each event carries viewInstanceId, which joins it back to the specific MobileView *visit* that
//  produced it, and previousView, which makes timings queryable by route rather than only by
//  destination screen.
//
//  See docs/superpowers/specs/2026-08-28-mobileview-timing-design.md
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Event type emitted for every view timing.
FOUNDATION_EXPORT NSString * const kNRMAViewTimingEventType;

/// The agent-owned timing, projected from the loadTime the agent already measures. Reserved: the
/// public API rejects it so the out-of-the-box series stays comparable across apps.
FOUNDATION_EXPORT NSString * const kNRMAViewTimingInitialDisplay;

/// Maximum *customer* timings recorded per view instance. The default event buffer holds 1000
/// events, so an unguarded markViewTiming: inside cellForRowAtIndexPath: would evict the customer's
/// own real events. Agent-owned timings do not count against this.
FOUNDATION_EXPORT const NSUInteger kNRMAViewTimingMaxPerViewInstance;

/// Longest accepted timing name, to bound attribute cardinality.
FOUNDATION_EXPORT const NSUInteger kNRMAViewTimingMaxNameLength;

/// Largest accepted duration (10 minutes). Catches the seconds-passed-where-milliseconds-expected
/// mistake instead of recording it as a ten-hour view load.
FOUNDATION_EXPORT const double kNRMAViewTimingMaxMilliseconds;

/**
 * Immutable copy of the current-view state.
 *
 * NRMAViewContext guards its state with a non-recursive os_unfair_lock, and emitting an event while
 * holding that lock risks both priority inversion and lock-order deadlock against the harvester.
 * So the flow is always: take the lock, copy into one of these, release the lock, then emit.
 */
@interface NRMAViewTimingSnapshot : NSObject

@property (nonatomic, readonly, copy, nullable) NSString *viewName;
@property (nonatomic, readonly, copy, nullable) NSString *viewInstanceId;
@property (nonatomic, readonly, copy, nullable) NSString *previousView;
@property (nonatomic, readonly, copy, nullable) NSString *uiPlatform;

/// When the current view became visible — the zero point markTimingNamed: measures from.
@property (nonatomic, readonly) CFAbsoluteTime appearTime;

/// NO when no view is current, in which case appearTime is meaningless.
@property (nonatomic, readonly) BOOL hasCurrentView;

- (instancetype)initWithViewName:(nullable NSString *)viewName
                  viewInstanceId:(nullable NSString *)viewInstanceId
                    previousView:(nullable NSString *)previousView
                      uiPlatform:(nullable NSString *)uiPlatform
                      appearTime:(CFAbsoluteTime)appearTime
                  hasCurrentView:(BOOL)hasCurrentView NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface NRMAViewTiming : NSObject

+ (instancetype)sharedInstance;

/// `init` returns a fresh instance with its own cap state. Used by tests so cap counters cannot
/// leak between cases; production code uses `sharedInstance`.
- (instancetype)init;

#pragma mark - Public API entry points

/// Records `name` measured from the current view's appear time to now.
/// Returns NO when view tracking is disabled, when no view is current (no zero point exists), or
/// when the timing fails validation or the per-view cap.
- (BOOL)markTimingNamed:(NSString *)name;

/// Records `name` with a caller-supplied duration. Unlike markTimingNamed:, this succeeds with no
/// view current — the row simply lands without view identity.
- (BOOL)recordTimingNamed:(NSString *)name milliseconds:(double)milliseconds;

#pragma mark - Agent-owned emission

/// Emits the out-of-the-box `timeToInitialDisplay` row for a view that just appeared, projected
/// from the loadTime the caller already measured. Exempt from the reserved-name check and from the
/// customer cap: the baseline must never be the row that gets dropped.
- (void)recordInitialDisplayForViewNamed:(NSString *)viewName
                              instanceId:(nullable NSString *)instanceId
                            previousView:(nullable NSString *)previousView
                                platform:(nullable NSString *)platform
                            milliseconds:(double)milliseconds;

#pragma mark - Decision layer

/// Validates and caps a timing, returning the attributes to emit, or nil if it must be dropped.
/// Separated from emission so it is testable without an agent or harvester. Counts a non-nil
/// result against the cap, so calling this is not free of side effects.
- (nullable NSDictionary<NSString *, id> *)attributesForTimingNamed:(NSString *)name
                                                      milliseconds:(double)milliseconds
                                                          snapshot:(NRMAViewTimingSnapshot *)snapshot
                                                        agentOwned:(BOOL)agentOwned;

@end

NS_ASSUME_NONNULL_END
