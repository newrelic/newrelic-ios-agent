//
//  NRMASessionFlowMonitor.h
//  NewRelicAgent
//
//  Accumulates the screen-flow graph and timeline for the session in progress and archives finished
//  ones.
//
//  This is the runtime half of scripts/mobileview_flow.py. The script reads a dump of MobileView
//  events after the fact; the monitor watches them go by, so the diagram for the session in progress
//  is available at any moment without a round trip to NRDB.
//
//  Three taps feed it:
//
//    -[NRMAAnalytics addViewEventOfType:withAttributes:]  — every MobileView and MobileViewTiming
//                                                          event the agent records, whichever
//                                                          producer made it, once it is accepted
//    +[NewRelic recordBreadcrumb:attributes:]             — after the referrer merge, so currentView
//                                                          is present
//    -[NRMAAnalytics endSessionReusable]                  — the one place the MobileSession event is
//                                                          created, which is what ends a diagram
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRSessionFlowDiagramOptions.h"

NS_ASSUME_NONNULL_BEGIN

/// How many finished sessions keep their diagram. Small on purpose: a diagram is a debugging aid
/// read minutes after the fact, and each one holds a graph and timeline for the whole session.
FOUNDATION_EXPORT const NSUInteger NRMASessionFlowArchiveLimit;

@interface NRMASessionFlowMonitor : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Ingest

/**
 * Folds one accepted MobileView or MobileViewTiming event into the current session's graph and
 * timeline. Other event types are ignored. `timestamp` (epoch ms) and `sessionElapsedSeconds` are
 * the event's own `timestamp` and `timeSinceLoad`, which place it on the timeline.
 */
- (void)recordViewEventOfType:(NSString *)eventType
                   attributes:(nullable NSDictionary<NSString *, id> *)attributes
                    timestamp:(double)timestamp
        sessionElapsedSeconds:(double)sessionElapsedSeconds;

/**
 * Attaches a breadcrumb to whichever screen was current when it was recorded, read from the
 * `currentView` the agent stamps on breadcrumbs. Breadcrumbs recorded before any view appeared have
 * no `currentView` and are dropped.
 */
- (void)recordBreadcrumbNamed:(nullable NSString *)name
                   attributes:(nullable NSDictionary<NSString *, id> *)attributes;

#pragma mark - Session lifecycle

/**
 * Ends the current diagram: archives it against the session id it was collected under and starts an
 * empty one. A session that recorded nothing is not archived.
 *
 * Deliberately emits no event. Called from the session-end path, which already runs under the
 * agent's background/foreground mutex, so recording an event here would re-enter the analytics stack
 * mid-teardown.
 */
- (void)finalizeCurrentSessionDiagram;

#pragma mark - Diagrams

/// Mermaid flowchart for the session in progress, or nil if no transition has been recorded yet.
- (nullable NSString *)mermaidForCurrentSessionWithOptions:(nullable NRSessionFlowDiagramOptions *)options;

/// Mermaid gantt for the session in progress, or nil if no visit has been recorded yet.
- (nullable NSString *)timelineForCurrentSessionWithOptions:(nullable NRSessionFlowDiagramOptions *)options;

/// Session ids that have an archived diagram, oldest first.
- (NSArray<NSString *> *)archivedSessionIds;

/// Mermaid flowchart for an archived session, or nil if that session id has none.
- (nullable NSString *)mermaidForSessionId:(NSString *)sessionId
                                   options:(nullable NRSessionFlowDiagramOptions *)options;

/// Mermaid gantt for an archived session, or nil if that session id has none.
- (nullable NSString *)timelineForSessionId:(NSString *)sessionId
                                    options:(nullable NRSessionFlowDiagramOptions *)options;

/// Screens / transitions / timings / breadcrumbs recorded so far this session, for a status line.
- (NSString *)currentSessionSummary;

/// Drops the live graph and the archive. Tests only.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
