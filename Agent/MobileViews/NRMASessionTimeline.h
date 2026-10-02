//
//  NRMASessionTimeline.h
//  NewRelicAgent
//
//  The raw material for one session's timeline: each MobileView visit and MobileViewTiming mark as it
//  was recorded, with its timestamp. Rendering lives in NRMASessionFlowRenderer.
//
//  Ported from build_timeline() and session_origin() in scripts/mobileview_flow.py. Rows are kept as
//  recorded and replayed through the script's algorithm at render time, rather than folded into
//  visits on arrival, so the visit list comes out exactly as the script builds it -- including which
//  row wins when two share a viewInstanceId, and the order visits that appear together sort in.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Rows kept per session. A visit is one row under the current one-event-per-visit contract, so this
/// is roughly the number of screens a session can show before the timeline stops growing.
FOUNDATION_EXPORT const NSUInteger NRMASessionTimelineMaxRows;

/// One visit, as the renderer draws it. Times are epoch milliseconds.
@interface NRMASessionTimelineVisit : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) double appear;
/// NaN when the visit had not ended when the session's rows stopped.
@property (nonatomic) double end;
/// NaN when the row carried no loadTime.
@property (nonatomic) double loadMilliseconds;
@property (nonatomic) BOOL reappeared;
/// Timing marks, each @[timestamp, timingName, value], in arrival order.
@property (nonatomic, readonly) NSMutableArray<NSArray *> *marks;
@end

@interface NRMASessionTimeline : NSObject <NSCopying>

/**
 * Stores one MobileView event. `timestamp` is the event's epoch-ms timestamp and
 * `sessionElapsedSeconds` its `timeSinceLoad`, which together pin the session's t=0.
 */
- (void)recordMobileViewAttributes:(nullable NSDictionary<NSString *, id> *)attributes
                         timestamp:(double)timestamp
             sessionElapsedSeconds:(double)sessionElapsedSeconds;

/// Stores one MobileViewTiming event, as recordMobileViewAttributes: does a MobileView event.
- (void)recordViewTimingAttributes:(nullable NSDictionary<NSString *, id> *)attributes
                         timestamp:(double)timestamp
             sessionElapsedSeconds:(double)sessionElapsedSeconds;

/**
 * Feeds the session origin without storing a row. The script takes t=0 from every event in a dump,
 * not just view events; this is how a replayed dump gives the same origin. Pass NaN for
 * `sessionElapsedSeconds` when the event carried no timeSinceLoad.
 */
- (void)noteEventAtTimestamp:(double)timestamp sessionElapsedSeconds:(double)sessionElapsedSeconds;

/**
 * The session's visits in the order they appeared, capped at `maximumVisits` (0 for no cap) —
 * build_timeline(). `dropped`, if given, receives how many later visits the cap cut.
 */
- (NSArray<NRMASessionTimelineVisit *> *)visitsWithMaximum:(NSUInteger)maximumVisits
                                                   dropped:(nullable NSUInteger *)dropped;

/// t=0 in epoch ms, NaN before any row. `exact` is YES when it came from timeSinceLoad (the real
/// session start) rather than the earliest timestamp seen (merely the start of recording).
- (double)originIsExact:(nullable BOOL *)exact;

@property (nonatomic, readonly) BOOL truncated;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

@end

NS_ASSUME_NONNULL_END
