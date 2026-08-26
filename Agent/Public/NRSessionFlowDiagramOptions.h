//
//  NRSessionFlowDiagramOptions.h
//  NewRelicAgent
//
//  Rendering options for the session flow diagram (see +[NewRelic currentSessionFlowDiagram]).
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Options controlling how a session's screen-flow graph is rendered as Mermaid.
 *
 * The defaults produce the same diagram as running `scripts/mobileview_flow.py` with no flags:
 * component segments folded into their screen, no breadcrumbs, every transition drawn, and
 * screens averaging 500 ms or more of load time highlighted.
 */
@interface NRSessionFlowDiagramOptions : NSObject <NSCopying>

/// Options matching the defaults of `scripts/mobileview_flow.py`.
+ (instancetype)defaultOptions;

/**
 * Draw component segments as their own nodes, nested in a subgraph under the screen they belong to.
 *
 * A component is a MobileView event carrying `component: YES` and `componentOf: <screen name>` —
 * a part of a screen rather than a destination the user navigated to. Default NO, which folds each
 * component onto its owning screen so a screen's internal segments do not masquerade as navigation
 * steps. Folded components also drop their own `loadTime` rather than skewing the screen's average.
 */
@property (nonatomic) BOOL includeComponents;

/**
 * Annotate each screen with the breadcrumbs recorded while it was the current view.
 *
 * Default NO, to keep the flow uncluttered. Breadcrumbs are always accumulated, so switching this
 * on renders the ones already collected — no need to set it before the session starts.
 */
@property (nonatomic) BOOL includeBreadcrumbs;

/**
 * Drop transitions traversed fewer than this many times. Default 1 (draw everything).
 *
 * Pruning can remove every edge, in which case the diagram accessors return nil rather than an
 * empty flowchart.
 */
@property (nonatomic) NSUInteger minimumTransitionCount;

/// Highlight screens whose average `loadTime` is at least this many milliseconds. Default 500.
@property (nonatomic) double slowLoadThresholdMilliseconds;

/// Optional title line for the diagram. Default nil (no title block).
@property (nonatomic, copy, nullable) NSString *title;

@end

NS_ASSUME_NONNULL_END
