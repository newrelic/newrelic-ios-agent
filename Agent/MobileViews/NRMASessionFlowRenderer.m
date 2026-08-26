//
//  NRMASessionFlowRenderer.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionFlowRenderer.h"

/// Stands in for the entry edge's absent source when sorting. The graph stores NSNull there; the
/// script stores this literal, and edge ordering depends on where it sorts among real view names, so
/// the comparator has to use the same string to produce the same order.
static NSString * const kNRMAStartSortKey = @"__start__";

#pragma mark - Label sanitizing

/// Node and breadcrumb labels are emitted inside double quotes, so only quotes and pipes need
/// handling.
static NSString *NRMASanitizeLabel(NSString *label) {
    NSString *text = [label stringByReplacingOccurrencesOfString:@"\"" withString:@"'"];
    text = [text stringByReplacingOccurrencesOfString:@"|" withString:@"/"];
    return [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

/// Edge labels sit bare between pipes, where Mermaid lexes their punctuation as shape tokens: a
/// literal "(" becomes PS and aborts the parse, so "3 (2 back)" is a parse error rather than a
/// label. Reduce them to letters, digits and spaces — no quoting form is safe across Mermaid
/// versions.
static NSString *NRMASanitizeEdgeLabel(NSString *label) {
    NSMutableString *text = [label mutableCopy];
    for (NSString *ch in @[@"(", @")", @"[", @"]", @"{", @"}", @"<", @">",
                           @"|", @"\"", @"'", @"`", @"-"]) {
        [text replaceOccurrencesOfString:ch withString:@" "
                                 options:0 range:NSMakeRange(0, text.length)];
    }
    NSArray<NSString *> *parts = [text componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length > 0) [kept addObject:part];
    }
    return [kept componentsJoinedByString:@" "];
}

#pragma mark - Folded working copy

/// A graph with component folding and edge pruning already applied, ready to emit. Built per render
/// so the underlying session graph stays option-independent.
@interface NRMASessionFlowRenderable : NSObject
@property (nonatomic) NSMutableDictionary<NSArray *, NSNumber *> *edges;
@property (nonatomic) NSMutableDictionary<NSArray *, NSNumber *> *back;
@property (nonatomic) NSMutableSet<NSString *> *nodes;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *loadTotals;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *loadCounts;
@property (nonatomic) NSDictionary<NSString *, NSString *> *componentOf;
@property (nonatomic) NSMutableDictionary<NSArray<NSString *> *, NSNumber *> *breadcrumbs;
@end

@implementation NRMASessionFlowRenderable
@end

@implementation NRMASessionFlowRenderer

/// collapse maps each component's view name onto the screen that owns it. Without it, excluding
/// component rows still leaves their names as edge endpoints, so a screen's internal segments
/// masquerade as navigation steps between real screens.
+ (NSString *)fold:(NSString *)name with:(NSDictionary<NSString *, NSString *> *)collapse {
    // Single lookup, not transitive — a component of a component resolves one level, matching the
    // script.
    return collapse[name] ?: name;
}

+ (NRMASessionFlowRenderable *)renderableForGraph:(NRMASessionFlowGraph *)graph
                                          options:(NRSessionFlowDiagramOptions *)options {
    NSDictionary<NSString *, NSString *> *collapse =
        options.includeComponents ? @{} : graph.componentOwners;

    NRMASessionFlowRenderable *r = [[NRMASessionFlowRenderable alloc] init];
    r.edges       = [NSMutableDictionary dictionary];
    r.back        = [NSMutableDictionary dictionary];
    r.nodes       = [NSMutableSet set];
    r.loadTotals  = [NSMutableDictionary dictionary];
    r.loadCounts  = [NSMutableDictionary dictionary];
    r.breadcrumbs = [NSMutableDictionary dictionary];
    // Component segments only render nested under their screen when they are drawn at all; once
    // folded, a segment *is* its owner and there is no subgraph to draw.
    r.componentOf = options.includeComponents ? graph.componentOwners : @{};

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

    [graph.loadTimeTotals enumerateKeysAndObjectsUsingBlock:^(NSString *view, NSNumber *total, BOOL *stop) {
        // A folded segment's loadTime is dropped rather than merged into its screen's average: it
        // measures a part of the screen, not the screen becoming visible.
        if (collapse.count > 0 && graph.componentOwners[view] != nil) return;
        r.loadTotals[view] = total;
        r.loadCounts[view] = graph.loadTimeCounts[view];
    }];

    [graph.breadcrumbCounts enumerateKeysAndObjectsUsingBlock:^(NSArray<NSString *> *key, NSNumber *count, BOOL *stop) {
        NSArray<NSString *> *folded = @[[self fold:key[0] with:collapse], key[1]];
        r.breadcrumbs[folded] = @(r.breadcrumbs[folded].unsignedIntegerValue + count.unsignedIntegerValue);
    }];

    if (options.minimumTransitionCount > 1) {
        NSMutableDictionary *kept = [NSMutableDictionary dictionary];
        for (NSArray *key in r.edges) {
            if (r.edges[key].unsignedIntegerValue >= options.minimumTransitionCount) {
                kept[key] = r.edges[key];
            }
        }
        r.edges = kept;
        NSMutableDictionary *keptBack = [NSMutableDictionary dictionary];
        NSMutableSet<NSString *> *keptNodes = [NSMutableSet set];
        for (NSArray *key in kept) {
            if (r.back[key] != nil) keptBack[key] = r.back[key];
            if (key[0] != [NSNull null]) [keptNodes addObject:key[0]];
            [keptNodes addObject:key[1]];
        }
        r.back = keptBack;
        // Only pruning drops nodes. Left alone, a screen reached by a self-transition alone stays in
        // the diagram as an isolated box, which is what the script does too.
        [r.nodes intersectSet:keptNodes];
    }

    return r;
}

#pragma mark - Rendering

+ (NSString *)mermaidForGraph:(NRMASessionFlowGraph *)graph
                      options:(NRSessionFlowDiagramOptions *)options {
    if (graph == nil) return nil;
    NRSessionFlowDiagramOptions *opts = [(options ?: [NRSessionFlowDiagramOptions defaultOptions]) copy];

    NRMASessionFlowRenderable *r = [self renderableForGraph:graph options:opts];
    if (r.edges.count == 0) return nil;

    NSArray<NSString *> *sortedNodes =
        [r.nodes.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSMutableDictionary<NSString *, NSString *> *ids = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < sortedNodes.count; i++) {
        ids[sortedNodes[i]] = [NSString stringWithFormat:@"v%lu", (unsigned long)i];
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (opts.title.length > 0) {
        [lines addObject:@"---"];
        [lines addObject:[NSString stringWithFormat:@"title: %@", NRMASanitizeLabel(opts.title)]];
        [lines addObject:@"---"];
    }
    [lines addObject:@"flowchart LR"];
    [lines addObject:@"    classDef slow fill:#fde2e2,stroke:#c0392b,stroke-width:2px;"];
    [lines addObject:@"    classDef entry fill:#eef6ff,stroke:#2c6fbb,stroke-width:1px;"];
    BOOL drawBreadcrumbs = opts.includeBreadcrumbs && r.breadcrumbs.count > 0;
    if (drawBreadcrumbs) {
        [lines addObject:@"    classDef breadcrumb fill:#fff8e1,stroke:#c9a227,stroke-dasharray: 3 3;"];
    }

    BOOL hasStart = NO;
    for (NSArray *key in r.edges) {
        if (key[0] == [NSNull null]) { hasStart = YES; break; }
    }
    if (hasStart) [lines addObject:@"    start(( )):::entry"];

    // Group in sorted order so members of each group come out sorted too.
    NSMutableArray<NSString *> *flatNodes = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *grouped = [NSMutableDictionary dictionary];
    for (NSString *node in sortedNodes) {
        NSString *owner = r.componentOf[node];
        if (owner == nil) {
            [flatNodes addObject:node];
        } else {
            NSMutableArray<NSString *> *members = grouped[owner];
            if (members == nil) { members = [NSMutableArray array]; grouped[owner] = members; }
            [members addObject:node];
        }
    }

    NSMutableArray<NSString *> *slowNodeIds = [NSMutableArray array];
    void (^emitNode)(NSString *, NSString *) = ^(NSString *node, NSString *indent) {
        NSUInteger samples = r.loadCounts[node].unsignedIntegerValue;
        NSString *label = NRMASanitizeLabel(node);
        if (samples > 0) {
            double average = r.loadTotals[node].doubleValue / (double)samples;
            label = [label stringByAppendingFormat:@"<br/>%.0f ms", average];
            if (average >= opts.slowLoadThresholdMilliseconds) {
                [slowNodeIds addObject:ids[node]];
            }
        }
        [lines addObject:[NSString stringWithFormat:@"%@%@[\"%@\"]", indent, ids[node], label]];
    };

    for (NSString *node in flatNodes) emitNode(node, @"    ");

    NSArray<NSString *> *owners = [grouped.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSUInteger i = 0; i < owners.count; i++) {
        NSString *owner = owners[i];
        [lines addObject:[NSString stringWithFormat:@"    subgraph sg_%lu[\"%@\"]",
                          (unsigned long)i, NRMASanitizeLabel(owner)]];
        [lines addObject:@"        direction TB"];
        for (NSString *node in grouped[owner]) emitNode(node, @"        ");
        [lines addObject:@"    end"];
    }

    NSArray<NSArray *> *edgeKeys = [r.edges.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
        NSUInteger ca = r.edges[a].unsignedIntegerValue, cb = r.edges[b].unsignedIntegerValue;
        if (ca != cb) return (ca > cb) ? NSOrderedAscending : NSOrderedDescending;  // busiest first
        NSString *sa = (a[0] == [NSNull null]) ? kNRMAStartSortKey : a[0];
        NSString *sb = (b[0] == [NSNull null]) ? kNRMAStartSortKey : b[0];
        NSComparisonResult bySource = [sa compare:sb];
        return (bySource != NSOrderedSame) ? bySource : [(NSString *)a[1] compare:b[1]];
    }];

    for (NSArray *key in edgeKeys) {
        NSString *sourceId = (key[0] == [NSNull null]) ? @"start" : ids[key[0]];
        NSString *targetId = ids[key[1]];
        if (sourceId == nil || targetId == nil) continue;  // endpoint pruned away

        NSUInteger count = r.edges[key].unsignedIntegerValue;
        NSUInteger back  = r.back[key].unsignedIntegerValue;
        NSString *arrow;
        if (back > 0 && back >= count) {
            // Purely a back-navigation: dashed, so a returning route never reads as a new one.
            NSString *label = (count > 1) ? [NSString stringWithFormat:@"%lu back", (unsigned long)count]
                                          : @"back";
            arrow = [NSString stringWithFormat:@"-.->|%@|", NRMASanitizeEdgeLabel(label)];
        } else if (back > 0) {
            // Mixed pair — traversed forward and returned along the same edge. Report the two counts
            // separately rather than a total plus a parenthetical.
            NSString *label = [NSString stringWithFormat:@"%lu fwd %lu back",
                               (unsigned long)(count - back), (unsigned long)back];
            arrow = [NSString stringWithFormat:@"-->|%@|", NRMASanitizeEdgeLabel(label)];
        } else if (count > 1) {
            arrow = [NSString stringWithFormat:@"-->|%@|",
                     NRMASanitizeEdgeLabel([NSString stringWithFormat:@"%lu", (unsigned long)count])];
        } else {
            arrow = @"-->";
        }
        [lines addObject:[NSString stringWithFormat:@"    %@ %@ %@", sourceId, arrow, targetId]];
    }

    for (NSString *nodeId in slowNodeIds) {
        [lines addObject:[NSString stringWithFormat:@"    class %@ slow;", nodeId]];
    }

    if (opts.includeBreadcrumbs) {
        NSArray<NSArray<NSString *> *> *crumbKeys =
            [r.breadcrumbs.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSArray<NSString *> *a, NSArray<NSString *> *b) {
                NSComparisonResult byView = [a[0] compare:b[0]];
                return (byView != NSOrderedSame) ? byView : [a[1] compare:b[1]];
            }];
        NSMutableArray<NSString *> *crumbIds = [NSMutableArray array];
        for (NSUInteger i = 0; i < crumbKeys.count; i++) {
            NSArray<NSString *> *key = crumbKeys[i];
            NSString *viewId = ids[key[0]];
            // Its view was pruned away or never became a node, so there is nothing to hang it off.
            if (viewId == nil) continue;
            NSUInteger count = r.breadcrumbs[key].unsignedIntegerValue;
            NSString *label = NRMASanitizeLabel(key[1]);
            if (count > 1) {
                label = [label stringByAppendingFormat:@" ×%lu", (unsigned long)count];
            }
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

@end
