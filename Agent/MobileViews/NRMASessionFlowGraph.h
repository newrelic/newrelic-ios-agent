//
//  NRMASessionFlowGraph.h
//  NewRelicAgent
//
//  The raw screen-flow data for one session: which transitions ran between which screens, how long
//  each screen took to load, which view timings were recorded on it, and which breadcrumbs were
//  recorded while it was current. Aggregation only — rendering lives in NRMASessionFlowRenderer.
//
//  Ported from the Graph class, build_graph(), add_timings() and add_breadcrumbs() in
//  scripts/mobileview_flow.py. Every MobileView event carries both ends of a transition (`viewName`
//  and `previousView`), so the graph is a plain aggregation over those pairs with no ordering
//  heuristics.
//
//  Everything is stored as it was recorded — before component folding, pruning, or attaching timings
//  to the routes a diagram draws — because the agent accumulates a session once and may render it
//  many times with different options. The renderer applies those per render, in the order the script
//  applies them.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Edge keys are two-element arrays: @[from, to]. `from` is an NSString, or NSNull for the synthetic
 * entry edge into the session's first screen. NSArray hashes on its contents, so this is a
 * collision-free composite key for names that may contain any character.
 */
typedef NSArray *NRMASessionFlowEdgeKey;

/// Upper bounds on one session's graph. A long session on a deeply dynamic screen hierarchy can mint
/// unbounded view names (list rows named after their content, say), and the graph lives for the whole
/// session. Past a cap the graph stops accepting *new* keys but keeps counting the ones it has, so a
/// truncated diagram still reflects real traffic rather than dying or growing without limit.
FOUNDATION_EXPORT const NSUInteger NRMASessionFlowMaxNodes;
FOUNDATION_EXPORT const NSUInteger NRMASessionFlowMaxEdges;
FOUNDATION_EXPORT const NSUInteger NRMASessionFlowMaxBreadcrumbs;
FOUNDATION_EXPORT const NSUInteger NRMASessionFlowMaxTimingSamples;

@interface NRMASessionFlowGraph : NSObject <NSCopying>

#pragma mark - Ingest

/**
 * Folds one MobileView event's attributes into the graph, applying the same row filter the script
 * does: disappear events (`appeared: NO`) and rows with no `viewName` add no transition. A row
 * flagged `component` with a `componentOf` still registers its owner either way, as the script reads
 * owners from every row.
 */
- (void)recordMobileViewAttributes:(nullable NSDictionary<NSString *, id> *)attributes;

/// Stores one MobileViewTiming event's `timingName` / `timingValue` against its `viewName` and the
/// `previousView` of the visit it was recorded in. Rows missing any of those three are dropped.
- (void)recordViewTimingAttributes:(nullable NSDictionary<NSString *, id> *)attributes;

/// Records breadcrumb `name` against the `currentView` the agent stamped on it. A breadcrumb with no
/// currentView predates any view appearing and is dropped.
- (void)recordBreadcrumbNamed:(nullable NSString *)name
                   attributes:(nullable NSDictionary<NSString *, id> *)attributes;

#pragma mark - Read

/// @[from, to] → traversal count, before folding. `from` is NSNull for the entry edge.
@property (nonatomic, readonly) NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *edgeCounts;
/// @[from, to] → how many of those traversals were back-navigations (`reappeared`).
@property (nonatomic, readonly) NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *backEdgeCounts;
/// Every view name that is an endpoint of some transition, component segments included.
@property (nonatomic, readonly) NSSet<NSString *> *nodes;
/// view name → summed loadTime, ms, from rows *not* flagged `component`.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *loadTimeTotals;
/// view name → number of those samples.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *loadTimeCounts;
/// As loadTimeTotals, for rows flagged `component`. Kept apart because folding drops them: a
/// segment's loadTime measures a part of a screen, not the screen becoming visible.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *componentLoadTimeTotals;
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *componentLoadTimeCounts;
/// component view name → owning screen, from every MobileView row. What folding collapses along.
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *componentOwners;
/// component view name → owning screen, from transition rows only. What nesting draws when
/// components are shown.
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *drawnComponentOwners;
/// Timing samples in arrival order, each @[viewName, previousView or NSNull, timingName, value].
@property (nonatomic, readonly) NSArray<NSArray *> *timingSamples;
/// @[view, breadcrumbName] → occurrences.
@property (nonatomic, readonly) NSDictionary<NSArray<NSString *> *, NSNumber *> *breadcrumbCounts;

/// YES once any cap was hit and data was dropped. Surfaced so a diagram can say so rather than
/// quietly under-reporting.
@property (nonatomic, readonly) BOOL truncated;

/// Nothing has been recorded yet, so there is no diagram to draw.
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

@end

NS_ASSUME_NONNULL_END
