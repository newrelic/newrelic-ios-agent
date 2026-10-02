//
//  NRMASessionFlowRenderer.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Structured to follow scripts/mobileview_flow.py function by function; each section names the
//  function it mirrors. Keep them in step.
//

#import "NRMASessionFlowRenderer.h"

/// Stands in for the entry edge's absent source when sorting. The graph stores NSNull there; the
/// script stores this literal, and edge ordering depends on where it sorts among real view names, so
/// the comparator has to use the same string to produce the same order.
static NSString * const kNRMAStartSortKey = @"__start__";

static NSString * const kNRMATimingInitialDisplay = @"timeToInitialDisplay";
static NSString * const kNRMATimingFullDisplay    = @"timeToFullDisplay";

/// MAX_LABEL_CHARS: widest screen name drawn in full. Dagre sizes a whole rank by its widest node.
static const NSUInteger kNRMAMaxLabelChars = 44;
/// LEAF_BOX_LINES: lines per folded-leaf box. Boxes stack vertically, so this caps one box's height.
static const NSUInteger kNRMALeafBoxLines = 13;
/// TTID_AT_APPEAR_MS: how far a TTID mark may sit from its load bar's end and still be that instant.
static const long long kNRMATTIDAtAppearMilliseconds = 5;
/// LOAD_TASK_ID: task-id prefix the timeline's themeCSS keys on to hide load-bar labels.
static NSString * const kNRMALoadTaskId = @"nrload";

#pragma mark - Strings (sanitize, shorten, sanitize_edge_label, sanitize_task, frontmatter_title)

/// Python's code-point-wise ordering of str, which the script sorts every name by. UTF-16 unit order
/// matches it everywhere outside the astral planes, which view names do not reach in practice.
static NSComparisonResult NRMACompare(NSString *a, NSString *b) {
    return [a compare:b options:NSLiteralSearch];
}

/// Node, subgraph and breadcrumb labels are emitted inside double quotes, so only quotes and pipes
/// need handling.
static NSString *NRMASanitizeLabel(NSString *label) {
    NSString *text = [label stringByReplacingOccurrencesOfString:@"\"" withString:@"'"];
    text = [text stringByReplacingOccurrencesOfString:@"|" withString:@"/"];
    return [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

/// Truncates a name for drawing, counting code points as Python's len() does.
static NSString *NRMAShorten(NSString *name) {
    __block NSUInteger count = 0;
    __block NSUInteger cutAt = NSNotFound;   // UTF-16 offset of code point number (limit - 1)
    [name enumerateSubstringsInRange:NSMakeRange(0, name.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange range, NSRange enclosing, BOOL *stop) {
        // A composed sequence can hold several code points (a letter plus a combining mark); walk
        // them individually so the count is Python's.
        for (NSUInteger i = 0; i < substring.length; i++) {
            unichar c = [substring characterAtIndex:i];
            if (CFStringIsSurrogateLowCharacter(c)) continue;
            if (count == kNRMAMaxLabelChars - 1) cutAt = range.location + i;
            count++;
        }
    }];
    if (count <= kNRMAMaxLabelChars) return name;
    return [[name substringToIndex:cutAt] stringByAppendingString:@"…"];
}

/// Collapses runs of whitespace to one space and trims the ends, as " ".join(text.split()) does.
static NSString *NRMACollapseWhitespace(NSString *text) {
    NSArray<NSString *> *parts = [text componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length > 0) [kept addObject:part];
    }
    return [kept componentsJoinedByString:@" "];
}

/// Edge labels sit bare between pipes, where Mermaid lexes their punctuation as shape tokens: a
/// literal "(" becomes PS and aborts the parse, so "3 (2 back)" is a parse error rather than a
/// label. Reduce them to letters, digits and spaces — no quoting form is safe across Mermaid
/// versions.
static NSString *NRMASanitizeEdgeLabel(NSString *label) {
    NSMutableString *text = [label mutableCopy];
    for (NSString *ch in @[@"(", @")", @"[", @"]", @"{", @"}", @"<", @">",
                           @"|", @"\"", @"'", @"`", @"-"]) {
        [text replaceOccurrencesOfString:ch withString:@" " options:0 range:NSMakeRange(0, text.length)];
    }
    return NRMACollapseWhitespace(text);
}

/// Gantt task names are terminated by ':' and fields split on ',', so neither can survive.
static NSString *NRMASanitizeTask(NSString *label) {
    NSMutableString *text = [label mutableCopy];
    for (NSString *ch in @[@":", @",", @";", @"#"]) {
        [text replaceOccurrencesOfString:ch withString:@" " options:0 range:NSMakeRange(0, text.length)];
    }
    return NRMACollapseWhitespace(text);
}

/// The title as a YAML scalar. Written bare, a title such as "App: checkout" is a YAML mapping
/// error and the whole render fails, so it is always double-quoted.
static NSString *NRMAFrontmatterTitle(NSString *title) {
    NSString *text = [title stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return [NSString stringWithFormat:@"\"%@\"", text];
}

/// f"{value:.0f}". Both round the exact binary value half-to-even, so the two agree digit for digit.
static NSString *NRMAWhole(double value) {
    return [NSString stringWithFormat:@"%.0f", value];
}

#pragma mark - Timings (median, timing_sort_key, abbrev)

static NSArray<NSString *> *NRMATimingOrder(void) {
    return @[kNRMATimingInitialDisplay, kNRMATimingFullDisplay, @"timeToInteractive", @"timeToFirstByte"];
}

static NSString *NRMAAbbrev(NSString *name) {
    NSDictionary<NSString *, NSString *> *abbrev = @{
        kNRMATimingInitialDisplay: @"TTID",
        kNRMATimingFullDisplay:    @"TTFD",
        @"timeToInteractive":      @"TTI",
        @"timeToFirstByte":        @"TTFB",
        @"firstInputDelay":        @"FID",
    };
    return abbrev[name] ?: name;
}

/// Lifecycle order for the known timings, then everything else alphabetically.
static NSComparisonResult NRMACompareTimingNames(NSString *a, NSString *b) {
    NSUInteger ia = [NRMATimingOrder() indexOfObject:a];
    NSUInteger ib = [NRMATimingOrder() indexOfObject:b];
    if (ia != NSNotFound && ib != NSNotFound) return ia < ib ? NSOrderedAscending : (ia > ib ? NSOrderedDescending : NSOrderedSame);
    if (ia != NSNotFound) return NSOrderedAscending;
    if (ib != NSNotFound) return NSOrderedDescending;
    return NRMACompare(a, b);
}

/// Median rather than mean: one pathological cold start should not redefine a screen. nil when empty.
static NSNumber *NRMAMedian(NSArray<NSNumber *> *values) {
    if (values.count == 0) return nil;
    NSArray<NSNumber *> *ordered = [values sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger mid = ordered.count / 2;
    if (ordered.count % 2) return @(ordered[mid].doubleValue);
    return @((ordered[mid - 1].doubleValue + ordered[mid].doubleValue) / 2.0);
}

#pragma mark - Working graph (Graph after build_graph, prune and add_timings)

/// A graph with component folding, pruning and timings applied, ready to emit. Built per render so
/// the underlying session graph stays option-independent.
@interface NRMASessionFlowRenderable : NSObject
@property (nonatomic) NSMutableDictionary<NSArray *, NSNumber *> *edges;
@property (nonatomic) NSMutableDictionary<NSArray *, NSNumber *> *back;
@property (nonatomic) NSMutableSet<NSString *> *nodes;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *loadTotals;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *loadCounts;
@property (nonatomic) NSDictionary<NSString *, NSString *> *componentOf;
/// view → timingName → values.
@property (nonatomic) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *> *timings;
/// @[from, to] → timingName → values.
@property (nonatomic) NSMutableDictionary<NSArray *, NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *> *edgeTimings;
@property (nonatomic) NSMutableDictionary<NSArray<NSString *> *, NSNumber *> *breadcrumbs;
@end

@implementation NRMASessionFlowRenderable

- (NSNumber *)averageLoad:(NSString *)view {
    NSUInteger n = self.loadCounts[view].unsignedIntegerValue;
    return n ? @(self.loadTotals[view].doubleValue / (double)n) : nil;
}

/// timing_medians(): @[@[name, median], ...] in lifecycle order.
- (NSArray<NSArray *> *)timingMedians:(NSString *)view {
    NSDictionary<NSString *, NSMutableArray<NSNumber *> *> *per = self.timings[view];
    if (per == nil) return @[];
    NSArray<NSString *> *names = [per.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return NRMACompareTimingNames(a, b);
    }];
    NSMutableArray<NSArray *> *out = [NSMutableArray array];
    for (NSString *name in names) {
        NSNumber *value = NRMAMedian(per[name]);
        if (value != nil) [out addObject:@[name, value]];
    }
    return out;
}

/// lie_window(): median TTFD minus median TTID, nil unless both exist. A screen with only the
/// baseline has nothing to compare against, and 0 would claim it was honest when it is merely
/// uninstrumented.
- (NSNumber *)lieWindow:(NSString *)view {
    NSDictionary<NSString *, NSMutableArray<NSNumber *> *> *per = self.timings[view];
    if (per.count == 0) return nil;
    NSNumber *ttid = NRMAMedian(per[kNRMATimingInitialDisplay]);
    NSNumber *ttfd = NRMAMedian(per[kNRMATimingFullDisplay]);
    if (ttid == nil || ttfd == nil) return nil;
    return @(ttfd.doubleValue - ttid.doubleValue);
}

/// headline_ms(): what the slow threshold is judged against. Full display over initial display,
/// because a screen that paints a spinner fast is not a fast screen; loadTime when it has neither.
- (NSNumber *)headline:(NSString *)view {
    NSDictionary<NSString *, NSMutableArray<NSNumber *> *> *per = self.timings[view];
    if (per.count > 0) {
        for (NSString *name in @[kNRMATimingFullDisplay, kNRMATimingInitialDisplay]) {
            NSNumber *value = NRMAMedian(per[name]);
            if (value != nil) return value;
        }
    }
    return [self averageLoad:view];
}

/// edge_landing_ms(): the median cost of landing on `to` via this route.
- (NSNumber *)landingOnEdge:(NSArray *)key {
    NSDictionary<NSString *, NSMutableArray<NSNumber *> *> *per = self.edgeTimings[key];
    if (per.count == 0) return nil;
    for (NSString *name in @[kNRMATimingFullDisplay, kNRMATimingInitialDisplay]) {
        NSNumber *value = NRMAMedian(per[name]);
        if (value != nil) return value;
    }
    return nil;
}

@end

@implementation NRMASessionFlowRenderer

+ (NSString *)fold:(NSString *)name with:(NSDictionary<NSString *, NSString *> *)collapse {
    // Single lookup, not transitive — a component of a component resolves one level, as in the script.
    return collapse[name] ?: name;
}

+ (NRMASessionFlowRenderable *)renderableForGraph:(NRMASessionFlowGraph *)graph
                                          options:(NRSessionFlowDiagramOptions *)options {
    // collapse maps each component's name onto the screen that owns it. Without it, a screen's
    // internal segments would masquerade as navigation steps between real screens.
    NSDictionary<NSString *, NSString *> *collapse = options.includeComponents ? @{} : graph.componentOwners;

    NRMASessionFlowRenderable *r = [[NRMASessionFlowRenderable alloc] init];
    r.edges       = [NSMutableDictionary dictionary];
    r.back        = [NSMutableDictionary dictionary];
    r.nodes       = [NSMutableSet set];
    r.loadTotals  = [NSMutableDictionary dictionary];
    r.loadCounts  = [NSMutableDictionary dictionary];
    r.timings     = [NSMutableDictionary dictionary];
    r.edgeTimings = [NSMutableDictionary dictionary];
    r.breadcrumbs = [NSMutableDictionary dictionary];
    // Nesting is only drawn when components are; folded, a segment *is* its owner.
    r.componentOf = options.includeComponents ? graph.drawnComponentOwners : @{};

    // build_graph()
    [graph.edgeCounts enumerateKeysAndObjectsUsingBlock:^(NSArray *key, NSNumber *count, BOOL *stop) {
        id rawFrom = key[0];
        NSString *to = [self fold:key[1] with:collapse];
        id from = (rawFrom == [NSNull null]) ? rawFrom : [self fold:rawFrom with:collapse];
        // Folding can collapse both ends onto one screen; that transition was internal to it.
        if (from != [NSNull null] && [(NSString *)from isEqualToString:to]) return;
        NSArray *folded = @[from, to];
        r.edges[folded] = @(r.edges[folded].unsignedIntegerValue + count.unsignedIntegerValue);
        NSNumber *back = graph.backEdgeCounts[key];
        if (back != nil) {
            r.back[folded] = @(r.back[folded].unsignedIntegerValue + back.unsignedIntegerValue);
        }
    }];
    for (NSString *node in graph.nodes) {
        [r.nodes addObject:[self fold:node with:collapse]];
    }

    void (^addLoads)(NSDictionary<NSString *, NSNumber *> *, NSDictionary<NSString *, NSNumber *> *) =
        ^(NSDictionary<NSString *, NSNumber *> *totals, NSDictionary<NSString *, NSNumber *> *counts) {
        [totals enumerateKeysAndObjectsUsingBlock:^(NSString *view, NSNumber *total, BOOL *stop) {
            NSString *dst = [self fold:view with:collapse];
            r.loadTotals[dst] = @(r.loadTotals[dst].doubleValue + total.doubleValue);
            r.loadCounts[dst] = @(r.loadCounts[dst].unsignedIntegerValue + counts[view].unsignedIntegerValue);
        }];
    };
    addLoads(graph.loadTimeTotals, graph.loadTimeCounts);
    // A folded segment's loadTime measures part of a screen, not the screen becoming visible.
    if (collapse.count == 0) addLoads(graph.componentLoadTimeTotals, graph.componentLoadTimeCounts);

    // add_breadcrumbs()
    [graph.breadcrumbCounts enumerateKeysAndObjectsUsingBlock:^(NSArray<NSString *> *key, NSNumber *count, BOOL *stop) {
        NSArray<NSString *> *folded = @[[self fold:key[0] with:collapse], key[1]];
        r.breadcrumbs[folded] = @(r.breadcrumbs[folded].unsignedIntegerValue + count.unsignedIntegerValue);
    }];

    // Graph.prune()
    if (options.minimumTransitionCount > 1) {
        NSMutableDictionary *kept = [NSMutableDictionary dictionary];
        NSMutableDictionary *keptBack = [NSMutableDictionary dictionary];
        NSMutableSet<NSString *> *keptNodes = [NSMutableSet set];
        for (NSArray *key in r.edges) {
            if (r.edges[key].unsignedIntegerValue < options.minimumTransitionCount) continue;
            kept[key] = r.edges[key];
            if (r.back[key] != nil) keptBack[key] = r.back[key];
            if (key[0] != [NSNull null]) [keptNodes addObject:key[0]];
            [keptNodes addObject:key[1]];
        }
        r.edges = kept;
        r.back = keptBack;
        [r.nodes intersectSet:keptNodes];
    }

    // add_timings(): after pruning, so timings only ever describe screens still on the diagram, and
    // a route's cost only ever labels a route that is drawn.
    if (options.includeTimings) {
        for (NSArray *sample in graph.timingSamples) {
            NSString *view = [self fold:sample[0] with:collapse];
            if (![r.nodes containsObject:view]) continue;
            NSString *previous = (sample[1] == [NSNull null]) ? nil : [self fold:sample[1] with:collapse];
            if (previous != nil && r.edges[@[previous, view]] == nil) previous = nil;
            NSString *name = sample[2];
            NSNumber *value = @([sample[3] doubleValue]);

            NSMutableDictionary *per = r.timings[view];
            if (per == nil) { per = [NSMutableDictionary dictionary]; r.timings[view] = per; }
            if (per[name] == nil) per[name] = [NSMutableArray array];
            [per[name] addObject:value];

            if (previous != nil) {
                NSArray *edge = @[previous, view];
                NSMutableDictionary *perEdge = r.edgeTimings[edge];
                if (perEdge == nil) { perEdge = [NSMutableDictionary dictionary]; r.edgeTimings[edge] = perEdge; }
                if (perEdge[name] == nil) perEdge[name] = [NSMutableArray array];
                [perEdge[name] addObject:value];
            }
        }
    }
    return r;
}

/// fold_leaves(): hubs whose plain one-hop screens draw as one grid instead of a node each.
///
/// A leaf of hub H: every edge touching it runs to or from H, it is not part of a component group,
/// it has no breadcrumbs drawn off it, and it carries at most one timing and no lie window.
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)leafGroupsIn:(NRMASessionFlowRenderable *)r
                                                      sortedNodes:(NSArray<NSString *> *)sortedNodes
                                                        threshold:(NSUInteger)minLeaves
                                                             keep:(NSSet<NSString *> *)keep {
    if (minLeaves < 2) return @{};
    NSMutableDictionary<NSString *, NSMutableSet *> *neighbours = [NSMutableDictionary dictionary];
    for (NSArray *key in r.edges) {
        id src = key[0] == [NSNull null] ? kNRMAStartSortKey : key[0];
        id dst = key[1];
        if (neighbours[src] == nil) neighbours[src] = [NSMutableSet set];
        if (neighbours[dst] == nil) neighbours[dst] = [NSMutableSet set];
        [neighbours[src] addObject:dst];
        [neighbours[dst] addObject:src];
    }
    NSSet<NSString *> *owners = [NSSet setWithArray:r.componentOf.allValues];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *groups = [NSMutableDictionary dictionary];
    for (NSString *node in sortedNodes) {
        NSSet *touching = neighbours[node];
        if (touching.count != 1) continue;
        NSString *hub = touching.anyObject;
        // A START-keyed neighbour set can only come from the entry edge; START is never a hub.
        if ([hub isEqualToString:kNRMAStartSortKey] && ![r.nodes containsObject:kNRMAStartSortKey]) continue;
        if ([owners containsObject:node] || r.componentOf[node] != nil || [keep containsObject:node]) continue;
        if ([r timingMedians:node].count > 1 || [r lieWindow:node] != nil) continue;
        if (groups[hub] == nil) groups[hub] = [NSMutableArray array];
        [groups[hub] addObject:node];
    }
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *out = [NSMutableDictionary dictionary];
    [groups enumerateKeysAndObjectsUsingBlock:^(NSString *hub, NSMutableArray<NSString *> *leaves, BOOL *stop) {
        if (leaves.count >= minLeaves) out[hub] = leaves;
    }];
    return out;
}

#pragma mark - Flow diagram (render)

+ (NSString *)mermaidForGraph:(NRMASessionFlowGraph *)graph options:(NRSessionFlowDiagramOptions *)options {
    if (graph == nil) return nil;
    NRSessionFlowDiagramOptions *opts = [(options ?: [NRSessionFlowDiagramOptions defaultOptions]) copy];

    NRMASessionFlowRenderable *r = [self renderableForGraph:graph options:opts];
    if (r.edges.count == 0) return nil;

    NSArray<NSString *> *sortedNodes = [r.nodes.allObjects sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return NRMACompare(a, b);
    }];
    NSMutableDictionary<NSString *, NSString *> *ids = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < sortedNodes.count; i++) {
        ids[sortedNodes[i]] = [NSString stringWithFormat:@"v%lu", (unsigned long)i];
    }

    NSMutableSet<NSString *> *crumbViews = [NSMutableSet set];
    if (opts.includeBreadcrumbs) {
        for (NSArray<NSString *> *key in r.breadcrumbs) [crumbViews addObject:key[0]];
    }
    NSDictionary<NSString *, NSArray<NSString *> *> *leafGroups =
        [self leafGroupsIn:r sortedNodes:sortedNodes threshold:opts.leafFoldingThreshold keep:crumbViews];
    NSArray<NSString *> *hubs = [leafGroups.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return NRMACompare(a, b);
    }];
    NSMutableSet<NSString *> *folded = [NSMutableSet set];
    for (NSString *hub in hubs) [folded addObjectsFromArray:leafGroups[hub]];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSMutableArray<NSString *> *front = [NSMutableArray array];
    if (opts.title.length > 0) {
        [front addObject:[NSString stringWithFormat:@"title: %@", NRMAFrontmatterTitle(opts.title)]];
    }
    if (leafGroups.count > 0) {
        // A leaf box line is past the default 200px wrap, and wrapped lines double a box's height.
        [front addObjectsFromArray:@[@"config:", @"  flowchart:", @"    wrappingWidth: 400"]];
    }
    if (front.count > 0) {
        [lines addObject:@"---"];
        [lines addObjectsFromArray:front];
        [lines addObject:@"---"];
    }
    [lines addObject:@"flowchart LR"];
    [lines addObject:@"    classDef slow fill:#fde2e2,stroke:#c0392b,stroke-width:2px;"];
    [lines addObject:@"    classDef entry fill:#eef6ff,stroke:#2c6fbb,stroke-width:1px;"];
    // Amber, distinct from slow-red: a screen can paint fast and still lie for a long time, and those
    // are different bugs with different fixes.
    [lines addObject:@"    classDef lying fill:#fff4e0,stroke:#c87f0a,stroke-width:2px;"];
    if (opts.includeBreadcrumbs && r.breadcrumbs.count > 0) {
        [lines addObject:@"    classDef breadcrumb fill:#fff8e1,stroke:#c9a227,stroke-dasharray: 3 3;"];
    }

    for (NSArray *key in r.edges) {
        if (key[0] == [NSNull null]) { [lines addObject:@"    start(( )):::entry"]; break; }
    }

    NSMutableArray<NSString *> *flatNodes = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *grouped = [NSMutableDictionary dictionary];
    for (NSString *node in sortedNodes) {
        NSString *owner = r.componentOf[node];
        if (owner == nil) {
            [flatNodes addObject:node];
        } else {
            if (grouped[owner] == nil) grouped[owner] = [NSMutableArray array];
            [grouped[owner] addObject:node];
        }
    }

    NSMutableArray<NSString *> *slowNodes = [NSMutableArray array];
    NSMutableArray<NSString *> *lyingNodes = [NSMutableArray array];
    double slowMs = opts.slowLoadThresholdMilliseconds;
    BOOL judgeLies = opts.includeTimings;
    double lieMs = opts.lieWindowThresholdMilliseconds;

    void (^emitNode)(NSString *, NSString *) = ^(NSString *node, NSString *indent) {
        NSMutableString *label = [NRMASanitizeLabel(NRMAShorten(node)) mutableCopy];
        NSArray<NSArray *> *medians = [r timingMedians:node];
        if (medians.count > 0) {
            // One line per timing, so a screen reads as a small table rather than one opaque number.
            for (NSArray *entry in medians) {
                [label appendFormat:@"<br/>%@ %@ ms", NRMASanitizeLabel(NRMAAbbrev(entry[0])),
                                    NRMAWhole([entry[1] doubleValue])];
            }
            NSNumber *lie = [r lieWindow:node];
            // Signed: TTFD can land before TTID, and "+-26" reads as a typo.
            if (lie != nil) [label appendFormat:@"<br/>lie %@ ms", [NSString stringWithFormat:@"%+.0f", lie.doubleValue]];
        } else {
            NSNumber *avg = [r averageLoad:node];
            if (avg != nil) [label appendFormat:@"<br/>%@ ms", NRMAWhole(avg.doubleValue)];
        }
        [lines addObject:[NSString stringWithFormat:@"%@%@[\"%@\"]", indent, ids[node], label]];

        NSNumber *headline = [r headline:node];
        if (headline != nil && headline.doubleValue >= slowMs) {
            [slowNodes addObject:ids[node]];
        } else if (judgeLies) {
            // Only flagged when not already red, so a screen carries one diagnosis, not two.
            NSNumber *lie = [r lieWindow:node];
            if (lie != nil && lie.doubleValue >= lieMs) [lyingNodes addObject:ids[node]];
        }
    };

    for (NSString *node in flatNodes) {
        if (![folded containsObject:node]) emitNode(node, @"    ");
    }

    // Each hub's leaves render as a stack of boxes, one line per screen. Slow screens share their own
    // red boxes, so the colour still says which ones they are.
    NSMutableDictionary<NSString *, NSString *> *groupIds = [NSMutableDictionary dictionary];
    for (NSUInteger gi = 0; gi < hubs.count; gi++) {
        NSString *hub = hubs[gi];
        NSArray<NSString *> *leaves = leafGroups[hub];
        NSString *groupId = [NSString stringWithFormat:@"leaves%lu", (unsigned long)gi];
        groupIds[hub] = groupId;
        [lines addObject:[NSString stringWithFormat:@"    subgraph %@[\"%lu screens opened from %@\"]",
                          groupId, (unsigned long)leaves.count, NRMASanitizeLabel(NRMAShorten(hub))]];
        // Unlinked boxes stack along the cross axis: down the page, for an LR graph.
        [lines addObject:@"        direction LR"];
        NSMutableArray<NSString *> *slow = [NSMutableArray array];
        NSMutableArray<NSString *> *plain = [NSMutableArray array];
        for (NSString *leaf in leaves) {
            NSNumber *headline = [r headline:leaf];
            [(headline != nil && headline.doubleValue >= slowMs ? slow : plain) addObject:leaf];
        }
        NSUInteger box = 0;
        for (NSArray *pass in @[@[slow, @YES], @[plain, @NO]]) {
            NSArray<NSString *> *members = pass[0];
            BOOL isSlow = [pass[1] boolValue];
            for (NSUInteger startAt = 0; startAt < members.count; startAt += kNRMALeafBoxLines) {
                NSMutableArray<NSString *> *entries = [NSMutableArray array];
                NSUInteger stopAt = MIN(startAt + kNRMALeafBoxLines, members.count);
                for (NSUInteger i = startAt; i < stopAt; i++) {
                    NSString *leaf = members[i];
                    NSMutableString *entry = [NRMASanitizeLabel(NRMAShorten(leaf)) mutableCopy];
                    NSArray<NSArray *> *medians = [r timingMedians:leaf];
                    NSNumber *avg = [r averageLoad:leaf];
                    if (medians.count > 0) {
                        [entry appendFormat:@" · %@ %@ ms", NRMASanitizeLabel(NRMAAbbrev(medians[0][0])),
                                            NRMAWhole([medians[0][1] doubleValue])];
                    } else if (avg != nil) {
                        [entry appendFormat:@" · %@ ms", NRMAWhole(avg.doubleValue)];
                    }
                    NSUInteger visits = r.edges[@[hub, leaf]].unsignedIntegerValue;
                    if (visits > 1) [entry appendFormat:@" · %lux", (unsigned long)visits];
                    [entries addObject:entry];
                }
                NSString *boxId = [NSString stringWithFormat:@"%@_%lu", groupId, (unsigned long)box++];
                [lines addObject:[NSString stringWithFormat:@"        %@[\"%@\"]", boxId,
                                  [entries componentsJoinedByString:@"<br/>"]]];
                if (isSlow) [slowNodes addObject:boxId];
            }
        }
        [lines addObject:@"    end"];
    }

    // Component segments render nested inside the screen they belong to.
    NSArray<NSString *> *owners = [grouped.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return NRMACompare(a, b);
    }];
    for (NSUInteger i = 0; i < owners.count; i++) {
        NSString *owner = owners[i];
        [lines addObject:[NSString stringWithFormat:@"    subgraph sg_%lu[\"%@\"]",
                          (unsigned long)i, NRMASanitizeLabel(NRMAShorten(owner))]];
        [lines addObject:@"        direction TB"];
        for (NSString *node in grouped[owner]) emitNode(node, @"        ");
        [lines addObject:@"    end"];
    }

    // One arrow into each leaf grid and one back out, standing in for an arrow pair per leaf.
    for (NSString *hub in hubs) {
        NSArray<NSString *> *leaves = leafGroups[hub];
        NSUInteger out = 0, into = 0, back = 0;
        for (NSString *leaf in leaves) {
            out  += r.edges[@[hub, leaf]].unsignedIntegerValue;
            into += r.edges[@[leaf, hub]].unsignedIntegerValue;
            back += r.back[@[leaf, hub]].unsignedIntegerValue;
        }
        NSString *label = out > leaves.count ? [NSString stringWithFormat:@"|%lux|", (unsigned long)out] : @"";
        [lines addObject:[NSString stringWithFormat:@"    %@ -->%@ %@", ids[hub], label, groupIds[hub]]];
        if (into > 0) {
            label = into > 1 ? [NSString stringWithFormat:@"|%lux|", (unsigned long)into] : @"";
            NSString *arrow = back >= into ? @"-.->" : @"-->";
            [lines addObject:[NSString stringWithFormat:@"    %@ %@%@ %@", groupIds[hub], arrow, label, ids[hub]]];
        }
    }

    NSArray<NSArray *> *edgeKeys = [r.edges.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
        NSUInteger ca = r.edges[a].unsignedIntegerValue, cb = r.edges[b].unsignedIntegerValue;
        if (ca != cb) return (ca > cb) ? NSOrderedAscending : NSOrderedDescending;  // busiest first
        NSString *sa = (a[0] == [NSNull null]) ? kNRMAStartSortKey : a[0];
        NSString *sb = (b[0] == [NSNull null]) ? kNRMAStartSortKey : b[0];
        NSComparisonResult bySource = NRMACompare(sa, sb);
        return (bySource != NSOrderedSame) ? bySource : NRMACompare(a[1], b[1]);
    }];

    for (NSArray *key in edgeKeys) {
        if ((key[0] != [NSNull null] && [folded containsObject:key[0]]) || [folded containsObject:key[1]]) continue;
        NSString *sourceId = (key[0] == [NSNull null]) ? @"start" : ids[key[0]];
        NSString *targetId = ids[key[1]];
        if (sourceId == nil || targetId == nil) continue;  // endpoint pruned away

        NSUInteger count = r.edges[key].unsignedIntegerValue;
        NSUInteger back  = r.back[key].unsignedIntegerValue;

        // Cost of landing on the target along *this* route. A screen that is quick from search and
        // slow from a deeplink shows up here and nowhere else on the diagram.
        NSNumber *landing = (opts.includeRouteTimings && key[0] != [NSNull null]) ? [r landingOnEdge:key] : nil;
        NSString *cost = landing != nil ? [NSString stringWithFormat:@" %@ ms", NRMAWhole(landing.doubleValue)] : @"";
        // "2x" rather than a bare "2", so a count never reads as part of the duration beside it.
        NSString *times = count > 1 ? [NSString stringWithFormat:@"%lux", (unsigned long)count] : @"";

        NSString *arrow;
        if (back > 0 && back >= count) {
            // Purely a back-navigation: dashed, so a returning route never reads as a new one.
            NSString *label = count > 1 ? [NSString stringWithFormat:@"%lu back", (unsigned long)count] : @"back";
            arrow = [NSString stringWithFormat:@"-.->|%@|", NRMASanitizeEdgeLabel([label stringByAppendingString:cost])];
        } else if (back > 0) {
            // Traversed forward and returned along the same edge: the two counts, not a total.
            NSString *label = [NSString stringWithFormat:@"%lu fwd %lu back",
                               (unsigned long)(count - back), (unsigned long)back];
            arrow = [NSString stringWithFormat:@"-->|%@|", NRMASanitizeEdgeLabel([label stringByAppendingString:cost])];
        } else if (count > 1) {
            arrow = [NSString stringWithFormat:@"-->|%@|", NRMASanitizeEdgeLabel([times stringByAppendingString:cost])];
        } else if (cost.length > 0) {
            arrow = [NSString stringWithFormat:@"-->|%@|", NRMASanitizeEdgeLabel(cost)];
        } else {
            arrow = @"-->";
        }
        [lines addObject:[NSString stringWithFormat:@"    %@ %@ %@", sourceId, arrow, targetId]];
    }

    for (NSString *nodeId in slowNodes) {
        [lines addObject:[NSString stringWithFormat:@"    class %@ slow;", nodeId]];
    }
    for (NSString *nodeId in lyingNodes) {
        [lines addObject:[NSString stringWithFormat:@"    class %@ lying;", nodeId]];
    }

    if (opts.includeBreadcrumbs) {
        NSArray<NSArray<NSString *> *> *crumbKeys =
            [r.breadcrumbs.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSArray<NSString *> *a, NSArray<NSString *> *b) {
                NSComparisonResult byView = NRMACompare(a[0], b[0]);
                return (byView != NSOrderedSame) ? byView : NRMACompare(a[1], b[1]);
            }];
        NSMutableArray<NSString *> *crumbIds = [NSMutableArray array];
        for (NSUInteger i = 0; i < crumbKeys.count; i++) {
            NSArray<NSString *> *key = crumbKeys[i];
            NSString *viewId = ids[key[0]];
            // Its view was pruned away or never became a node, so there is nothing to hang it off.
            if (viewId == nil) continue;
            NSUInteger count = r.breadcrumbs[key].unsignedIntegerValue;
            NSMutableString *label = [NRMASanitizeLabel(NRMAShorten(key[1])) mutableCopy];
            if (count > 1) [label appendFormat:@" ×%lu", (unsigned long)count];
            // Index, not a running counter: skipped crumbs leave gaps in the ids, as in the script.
            NSString *crumbId = [NSString stringWithFormat:@"b%lu", (unsigned long)i];
            [lines addObject:[NSString stringWithFormat:@"    %@([\"%@\"])", crumbId, label]];
            [lines addObject:[NSString stringWithFormat:@"    %@ -.-> %@", viewId, crumbId]];
            [crumbIds addObject:crumbId];
        }
        for (NSString *crumbId in crumbIds) {
            [lines addObject:[NSString stringWithFormat:@"    class %@ breadcrumb;", crumbId]];
        }
    }

    return [lines componentsJoinedByString:@"\n"];
}

#pragma mark - Timeline (render_timeline, timeline_visit_tasks)

/// Python's truthiness for an optional number: present and non-zero.
static BOOL NRMAPresent(double value) {
    return !isnan(value) && value != 0;
}

+ (NSString *)timelineMermaidForTimeline:(NRMASessionTimeline *)timeline
                                 options:(NRSessionFlowDiagramOptions *)options {
    if (timeline == nil) return nil;
    NRSessionFlowDiagramOptions *opts = [(options ?: [NRSessionFlowDiagramOptions defaultOptions]) copy];

    BOOL exact = NO;
    double origin = [timeline originIsExact:&exact];
    if (isnan(origin)) return nil;
    NSArray<NRMASessionTimelineVisit *> *visits = [timeline visitsWithMaximum:opts.maximumTimelineVisits dropped:NULL];
    if (visits.count == 0) return nil;

    long long (^rel)(double) = ^long long(double value) {
        return (long long)(value - origin);   // int(): truncation toward zero, as in the script
    };

    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:@"---"];
    if (opts.title.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"title: %@", NRMAFrontmatterTitle(opts.title)]];
    }
    // Compact packs a section's non-overlapping tasks onto one row, so with one section per screen
    // the chart is as tall as the number of screens rather than the number of tasks. The load bar's
    // label is hidden because its number moves onto the visible bar beside it, where the two would
    // otherwise print over each other.
    [lines addObjectsFromArray:@[@"config:", @"  gantt:", @"    displayMode: compact",
        [NSString stringWithFormat:@"  themeCSS: 'text[id*=\"-%@\"] { display: none; }'", kNRMALoadTaskId],
        @"---"]];
    [lines addObject:@"gantt"];
    [lines addObject:@"    dateFormat x"];
    [lines addObject:[NSString stringWithFormat:@"    axisFormat %@", opts.timelineAxisFormat ?: @"%M:%S"]];
    [lines addObject:@"    todayMarker off"];

    double sessionEnd = -INFINITY;
    for (NRMASessionTimelineVisit *visit in visits) {
        sessionEnd = MAX(sessionEnd, NRMAPresent(visit.end) ? visit.end : visit.appear);
    }

    [lines addObject:[NSString stringWithFormat:@"    section %@", NRMASanitizeTask(exact ? @"session start" : @"first event")]];
    // Zero-length span, both fields dates: the bare "0" duration form is not portable across
    // Mermaid versions, so a milestone always gets an explicit equal start and end.
    [lines addObject:@"    t0 :milestone, 0, 0"];

    // One section per screen, in order of first appearance, holding every visit to it.
    NSMutableArray<NSString *> *screenOrder = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NRMASessionTimelineVisit *> *> *byScreen = [NSMutableDictionary dictionary];
    for (NRMASessionTimelineVisit *visit in visits) {
        if (byScreen[visit.name] == nil) {
            byScreen[visit.name] = [NSMutableArray array];
            [screenOrder addObject:visit.name];
        }
        [byScreen[visit.name] addObject:visit];
    }

    NSUInteger task = 0;
    for (NSString *name in screenOrder) {
        NSArray<NRMASessionTimelineVisit *> *screenVisits = byScreen[name];
        [lines addObject:[NSString stringWithFormat:@"    section %@", NRMASanitizeTask(NRMAShorten(name))]];
        for (NSUInteger n = 0; n < screenVisits.count; n++) {
            NRMASessionTimelineVisit *visit = screenVisits[n];
            task++;
            BOOL numbered = screenVisits.count > 1;
            BOOL hasLoad = NRMAPresent(visit.loadMilliseconds);
            long long loadMs = hasLoad ? (long long)visit.loadMilliseconds : 0;
            long long appear = rel(visit.appear);

            // The construction window the agent measured as loadTime, drawn before the appearance.
            if (hasLoad) {
                [lines addObject:[NSString stringWithFormat:@"    load %lldms :done, %@%lu, %lld, %lld",
                                  loadMs, kNRMALoadTaskId, (unsigned long)task, appear - loadMs, appear]];
            }

            long long end = rel(NRMAPresent(visit.end) ? visit.end : sessionEnd);
            // Still on screen when recording stopped; give it a sliver so the bar is visible.
            if (end <= appear) end = appear + 1;
            // A re-appearance constructed nothing, so it gets a red outline over grey: it stands out
            // without reading as a problem, which solid `crit` would.
            NSString *state = visit.reappeared ? @"crit, done" : @"active";
            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            if (numbered) [parts addObject:[NSString stringWithFormat:@"visit %lu", (unsigned long)(n + 1)]];
            if (hasLoad) [parts addObject:[NSString stringWithFormat:@"load %lldms", loadMs]];
            NSString *label = parts.count > 0 ? [parts componentsJoinedByString:@" · "] : @"visible";
            [lines addObject:[NSString stringWithFormat:@"    %@ :%@, %lld, %lld", label, state, appear, end]];

            // sorted(marks): by timestamp, then name, then value.
            NSArray<NSArray *> *marks = [visit.marks sortedArrayUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
                NSComparisonResult byTime = [(NSNumber *)a[0] compare:b[0]];
                if (byTime != NSOrderedSame) return byTime;
                NSComparisonResult byName = NRMACompare(a[1], b[1]);
                return byName != NSOrderedSame ? byName : [(NSNumber *)a[2] compare:b[2]];
            }];
            for (NSArray *mark in marks) {
                long long at = rel([mark[0] doubleValue]);
                // The load bar already ends at this instant with this number on it, and a diamond
                // inside the visible bar would cost the screen a second row.
                if ([mark[1] isEqualToString:kNRMATimingInitialDisplay] && hasLoad
                        && llabs(at - appear) <= kNRMATTIDAtAppearMilliseconds) {
                    continue;
                }
                NSString *text = [NSString stringWithFormat:@"%@ %@ms", NRMAAbbrev(mark[1]), NRMAWhole([mark[2] doubleValue])];
                [lines addObject:[NSString stringWithFormat:@"    %@ :milestone, %lld, %lld", NRMASanitizeTask(text), at, at]];
            }
        }
    }

    return [lines componentsJoinedByString:@"\n"];
}

@end
