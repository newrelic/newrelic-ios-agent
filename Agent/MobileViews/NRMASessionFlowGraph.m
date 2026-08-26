//
//  NRMASessionFlowGraph.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionFlowGraph.h"
#import "NRLogger.h"

const NSUInteger NRMASessionFlowMaxNodes       = 200;
const NSUInteger NRMASessionFlowMaxEdges       = 2000;
const NSUInteger NRMASessionFlowMaxBreadcrumbs = 500;

@implementation NRMASessionFlowGraph {
    NSMutableDictionary<NRMASessionFlowEdgeKey, NSNumber *> *_edgeCounts;
    NSMutableDictionary<NRMASessionFlowEdgeKey, NSNumber *> *_backEdgeCounts;
    NSMutableSet<NSString *> *_nodes;
    NSMutableDictionary<NSString *, NSNumber *> *_loadTimeTotals;
    NSMutableDictionary<NSString *, NSNumber *> *_loadTimeCounts;
    NSMutableDictionary<NSString *, NSString *> *_componentOwners;
    NSMutableDictionary<NSArray<NSString *> *, NSNumber *> *_breadcrumbCounts;
    BOOL _truncated;
    BOOL _loggedTruncation;
}

- (instancetype)init {
    if ((self = [super init])) {
        _edgeCounts       = [NSMutableDictionary dictionary];
        _backEdgeCounts   = [NSMutableDictionary dictionary];
        _nodes            = [NSMutableSet set];
        _loadTimeTotals   = [NSMutableDictionary dictionary];
        _loadTimeCounts   = [NSMutableDictionary dictionary];
        _componentOwners  = [NSMutableDictionary dictionary];
        _breadcrumbCounts = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Truncation

// Notes that a cap was hit. Logged once per graph: the caps are reached by a pathological naming
// scheme, which would otherwise log on every subsequent transition for the rest of the session.
- (void)markTruncated:(NSString *)what {
    _truncated = YES;
    if (!_loggedTruncation) {
        _loggedTruncation = YES;
        NRLOG_AGENT_VERBOSE(@"[SessionFlow] diagram truncated: %@ cap reached. The diagram will "
                            @"keep counting known screens but stop adding new ones.", what);
    }
}

// A node is admissible if it already exists or there is room for one more.
- (BOOL)canAdmitNode:(NSString *)node {
    return [_nodes containsObject:node] || _nodes.count < NRMASessionFlowMaxNodes;
}

#pragma mark - Ingest

- (void)addTransitionFrom:(NSString *)from to:(NSString *)to isBack:(BOOL)isBack {
    if (to.length == 0) return;

    // A move between two segments of one screen is not navigation; keep the node, drop the edge.
    if (from != nil && [from isEqualToString:to]) {
        if ([self canAdmitNode:to]) {
            [_nodes addObject:to];
        } else {
            [self markTruncated:@"node"];
        }
        return;
    }

    // Both endpoints have to fit, or the edge would reference a node the renderer never emits.
    if (![self canAdmitNode:to] || (from != nil && ![self canAdmitNode:from])) {
        [self markTruncated:@"node"];
        return;
    }

    NRMASessionFlowEdgeKey key = @[from ?: (id)[NSNull null], to];
    if (_edgeCounts[key] == nil && _edgeCounts.count >= NRMASessionFlowMaxEdges) {
        [self markTruncated:@"edge"];
        return;
    }

    _edgeCounts[key] = @(_edgeCounts[key].unsignedIntegerValue + 1);
    if (isBack) {
        _backEdgeCounts[key] = @(_backEdgeCounts[key].unsignedIntegerValue + 1);
    }
    if (from != nil) [_nodes addObject:from];
    [_nodes addObject:to];
}

- (void)addLoadTimeMilliseconds:(double)milliseconds forView:(NSString *)view {
    if (view.length == 0) return;
    // Load samples are only ever read for views the graph already knows, so no separate cap: the
    // node cap already bounds how many keys can appear here.
    if (![self canAdmitNode:view]) {
        [self markTruncated:@"node"];
        return;
    }
    _loadTimeTotals[view] = @(_loadTimeTotals[view].doubleValue + milliseconds);
    _loadTimeCounts[view] = @(_loadTimeCounts[view].unsignedIntegerValue + 1);
}

- (void)noteView:(NSString *)view asComponentOfScreen:(NSString *)owner {
    if (view.length == 0 || owner.length == 0) return;
    _componentOwners[view] = owner;
}

- (void)addBreadcrumbNamed:(NSString *)name forView:(NSString *)view {
    if (name.length == 0 || view.length == 0) return;
    NSArray<NSString *> *key = @[view, name];
    if (_breadcrumbCounts[key] == nil && _breadcrumbCounts.count >= NRMASessionFlowMaxBreadcrumbs) {
        [self markTruncated:@"breadcrumb"];
        return;
    }
    _breadcrumbCounts[key] = @(_breadcrumbCounts[key].unsignedIntegerValue + 1);
}

#pragma mark - Read

- (NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *)edgeCounts       { return _edgeCounts; }
- (NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *)backEdgeCounts   { return _backEdgeCounts; }
- (NSSet<NSString *> *)nodes                                          { return _nodes; }
- (NSDictionary<NSString *, NSNumber *> *)loadTimeTotals               { return _loadTimeTotals; }
- (NSDictionary<NSString *, NSNumber *> *)loadTimeCounts               { return _loadTimeCounts; }
- (NSDictionary<NSString *, NSString *> *)componentOwners              { return _componentOwners; }
- (NSDictionary<NSArray<NSString *> *, NSNumber *> *)breadcrumbCounts  { return _breadcrumbCounts; }
- (BOOL)truncated                                                     { return _truncated; }

- (BOOL)isEmpty {
    return _edgeCounts.count == 0 && _nodes.count == 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %lu screens, %lu transitions, %lu breadcrumbs%@>",
            NSStringFromClass([self class]), (unsigned long)_nodes.count,
            (unsigned long)_edgeCounts.count, (unsigned long)_breadcrumbCounts.count,
            _truncated ? @", truncated" : @""];
}

@end
