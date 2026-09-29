//
//  NRMASessionFlowRenderer.h
//  NewRelicAgent
//
//  Renders an NRMASessionFlowGraph as a Mermaid flowchart, and an NRMASessionTimeline as a Mermaid
//  gantt.
//
//  Ported from render(), fold_leaves(), add_timings() and render_timeline() in
//  scripts/mobileview_flow.py, and byte-compatible with them: the same events rendered with the same
//  options produce the same Mermaid. A change to either output belongs in both places.
//
//  Two things move from build time to render time relative to the script, because the agent
//  accumulates a session's graph once and may render it many times with different options:
//
//    * Component folding. The script decides --include-components before building the graph; the
//      graph here keeps component segments as nodes plus a componentOf map, and folding happens on a
//      working copy per render.
//    * Pruning, and attaching timings to the routes that survive it. Likewise --min-count.
//
//  One deliberate output difference: the script names component subgraphs
//  `sg_{abs(hash(owner)) % 100000}`, and Python's string hash is seed-randomized per process, so
//  that id changes between runs of the same input. This renderer uses the owner's index in sorted
//  order, which is stable.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMASessionFlowGraph.h"
#import "NRMASessionTimeline.h"
#import "NRSessionFlowDiagramOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionFlowRenderer : NSObject

/**
 * Mermaid flowchart for `graph`, or nil when there is nothing to draw — no transitions recorded, or
 * `minimumTransitionCount` pruned them all away. Never returns an empty flowchart, because a
 * flowchart with no edges renders as a blank page and reads as a bug rather than as "no data".
 *
 * Pass nil options for +[NRSessionFlowDiagramOptions defaultOptions].
 */
+ (nullable NSString *)mermaidForGraph:(NRMASessionFlowGraph *)graph
                               options:(nullable NRSessionFlowDiagramOptions *)options;

/**
 * Mermaid gantt for `timeline`: one row per screen, one bar per visit, its load window before it and
 * its timing marks as diamonds, on one time axis from the start of the session. nil when no visit
 * has been recorded.
 */
+ (nullable NSString *)timelineMermaidForTimeline:(NRMASessionTimeline *)timeline
                                          options:(nullable NRSessionFlowDiagramOptions *)options;

@end

NS_ASSUME_NONNULL_END
