//
//  NRMASessionFlowGraph.h
//  NewRelicAgent
//
//  The screen-flow graph for one session: which screens were visited, which transitions ran between
//  them, how long each screen took to load, and which breadcrumbs were recorded while each was
//  current. Aggregation only — rendering lives in NRMASessionFlowRenderer.
//
//  Ported from the Graph class and build_graph() in scripts/mobileview_flow.py. Every MobileView
//  *appear* event carries both ends of a transition (`viewName` and `previousView`), so the graph is
//  a plain aggregation over those pairs with no ordering heuristics.
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

@interface NRMASessionFlowGraph : NSObject

#pragma mark - Ingest

/**
 * Records one traversal from `from` to `to`. Pass nil for `from` to record the entry into the
 * session's first screen, which renders as the diagram's start node.
 *
 * `isBack` marks the traversal as a return along a route already taken — the agent's `reappeared`
 * attribute. Back traversals are counted separately so a returning route renders dashed instead of
 * reading as a new one.
 *
 * A self-transition (`from` equal to `to`) records the node but no edge: it means the move was
 * between two segments of a single screen, not navigation.
 */
- (void)addTransitionFrom:(nullable NSString *)from to:(NSString *)to isBack:(BOOL)isBack;

/// Adds one `loadTime` sample, in milliseconds, for `view`. Averaged at render time.
- (void)addLoadTimeMilliseconds:(double)milliseconds forView:(NSString *)view;

/// Records that `view` is a component segment of the screen `owner`, rather than a destination.
- (void)noteView:(NSString *)view asComponentOfScreen:(NSString *)owner;

/// Records that breadcrumb `name` was recorded while `view` was the current view.
- (void)addBreadcrumbNamed:(NSString *)name forView:(NSString *)view;

#pragma mark - Read

/// @[from, to] → traversal count. `from` is NSNull for the entry edge.
@property (nonatomic, readonly) NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *edgeCounts;
/// @[from, to] → how many of those traversals were back-navigations. Subset of edgeCounts' keys.
@property (nonatomic, readonly) NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *backEdgeCounts;
/// Every view name that is an endpoint of some transition, component segments included.
@property (nonatomic, readonly) NSSet<NSString *> *nodes;
/// view name → summed loadTime samples, in milliseconds.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *loadTimeTotals;
/// view name → number of loadTime samples.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *loadTimeCounts;
/// component view name → the screen it belongs to.
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *componentOwners;
/// @[view, breadcrumbName] → occurrences.
@property (nonatomic, readonly) NSDictionary<NSArray<NSString *> *, NSNumber *> *breadcrumbCounts;

/// YES once any cap was hit and data was dropped. Surfaced so a diagram can say so rather than
/// quietly under-reporting.
@property (nonatomic, readonly) BOOL truncated;

/// Nothing has been recorded yet, so there is no diagram to draw.
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

@end

NS_ASSUME_NONNULL_END
