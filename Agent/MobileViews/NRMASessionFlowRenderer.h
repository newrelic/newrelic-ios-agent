//
//  NRMASessionFlowRenderer.h
//  NewRelicAgent
//
//  Renders an NRMASessionFlowGraph as a Mermaid flowchart.
//
//  Ported from render() / sanitize() / sanitize_edge_label() in scripts/mobileview_flow.py, and
//  byte-compatible with it — see NRMASessionFlowTests, which asserts against output captured from
//  the script.
//
//  Two things move from build time to render time relative to the script, because the agent
//  accumulates a session's graph once and may render it many times with different options:
//
//    * Component folding. The script decides --include-components before building the graph; the
//      graph here keeps component segments as nodes plus a componentOf map, and folding happens on a
//      working copy per render.
//    * Pruning. Likewise --min-count.
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
#import "NRSessionFlowDiagramOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionFlowRenderer : NSObject

/**
 * Mermaid source for `graph`, or nil when there is nothing to draw — no transitions recorded, or
 * `minimumTransitionCount` pruned them all away. Never returns an empty flowchart, because a
 * flowchart with no edges renders as a blank page and reads as a bug rather than as "no data".
 *
 * Pass nil options for +[NRSessionFlowDiagramOptions defaultOptions].
 */
+ (nullable NSString *)mermaidForGraph:(NRMASessionFlowGraph *)graph
                               options:(nullable NRSessionFlowDiagramOptions *)options;

@end

NS_ASSUME_NONNULL_END
