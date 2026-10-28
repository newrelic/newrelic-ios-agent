//
//  NRSessionFlowDiagramOptions.h
//  NewRelicAgent
//
//  Rendering options for the session flow diagram and timeline (see
//  +[NewRelic currentSessionFlowDiagram] and +[NewRelic currentSessionTimeline]).
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Options controlling how a session's screen flow is rendered as Mermaid.
 *
 * The defaults produce the same output as `scripts/mobileview_flow.py` with no flags (and, for the
 * timeline, `--timeline`): component segments folded into their screen, no breadcrumbs, every
 * transition drawn, view timings and route costs shown, screens at 500 ms or more highlighted red
 * and lie windows of 250 ms or more amber, leaf screens grouped once a screen has 6 of them, and the
 * first 25 visits on the timeline.
 */
@interface NRSessionFlowDiagramOptions : NSObject <NSCopying>

/// Options matching the defaults of `scripts/mobileview_flow.py`.
+ (instancetype)defaultOptions;

#pragma mark - Flow diagram

/**
 * Draw component segments as their own nodes, nested in a subgraph under the screen they belong to.
 *
 * A component is a MobileView event carrying `component: YES` and `componentOf: <screen name>` —
 * a part of a screen rather than a destination the user navigated to. Default NO, which folds each
 * component onto its owning screen so a screen's internal segments do not masquerade as navigation
 * steps. Folded components also drop their own `loadTime` rather than skewing the screen's average.
 * `--include-components` in the script.
 */
@property (nonatomic) BOOL includeComponents;

/**
 * Annotate each screen with the breadcrumbs recorded while it was the current view.
 *
 * Default NO, to keep the flow uncluttered. Breadcrumbs are always accumulated, so switching this
 * on renders the ones already collected — no need to set it before the session starts.
 * `--include-breadcrumbs` in the script.
 */
@property (nonatomic) BOOL includeBreadcrumbs;

/**
 * Label screens with their MobileViewTiming medians (TTID, TTFD, ...) and lie window. Default YES.
 * NO labels screens with average loadTime only, as `--no-timings` does.
 */
@property (nonatomic) BOOL includeTimings;

/**
 * Label each arrow with the median cost of landing on its screen along that route. Default YES; NO
 * is `--no-edge-timings`.
 */
@property (nonatomic) BOOL includeRouteTimings;

/**
 * Drop transitions traversed fewer than this many times. Default 1 (draw everything). `--min-count`.
 *
 * Pruning can remove every edge, in which case the diagram accessors return nil rather than an
 * empty flowchart.
 */
@property (nonatomic) NSUInteger minimumTransitionCount;

/**
 * Highlight a screen red when its median full-display time (or initial display, or average
 * loadTime, whichever it has) is at least this many milliseconds. Default 500. `--slow-ms`.
 */
@property (nonatomic) double slowLoadThresholdMilliseconds;

/**
 * Highlight a screen amber when its lie window — full display minus initial display, how long it
 * looked finished but was not — is at least this many milliseconds. Default 250. `--lie-ms`.
 */
@property (nonatomic) double lieWindowThresholdMilliseconds;

/**
 * Once a screen has at least this many leaves — screens entered from it and left back to it, with
 * at most one timing — draw them as one stacked grid of boxes instead of a node each. Keeps a home
 * screen that opens dozens of others from rendering as one enormous column. Default 6; 0 draws every
 * screen as its own node. `--fold-leaves`.
 */
@property (nonatomic) NSUInteger leafFoldingThreshold;

#pragma mark - Timeline

/// Keep the first this-many visits on the timeline; 0 keeps them all. Default 25. `--max-visits`.
@property (nonatomic) NSUInteger maximumTimelineVisits;

/// d3 time format for the timeline's axis. Default @"%M:%S". `--axis-format`.
@property (nonatomic, copy) NSString *timelineAxisFormat;

#pragma mark - Both

/// Optional title line. Default nil (no title). `--title`.
@property (nonatomic, copy, nullable) NSString *title;

@end

NS_ASSUME_NONNULL_END
