//
//  NRMASessionFlowGraph.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionFlowGraph.h"
#import "NRLogger.h"

const NSUInteger NRMASessionFlowMaxNodes         = 200;
const NSUInteger NRMASessionFlowMaxEdges         = 2000;
const NSUInteger NRMASessionFlowMaxBreadcrumbs   = 500;
const NSUInteger NRMASessionFlowMaxTimingSamples = 5000;

// MobileView / MobileViewTiming / MobileBreadcrumb attribute keys. Same schema as
// NRMAMobileViewTracker, NRMAViewTiming and NRMAViewContext emit, and as the script reads.
static NSString * const kNRAttr_viewName     = @"viewName";
static NSString * const kNRAttr_previousView = @"previousView";
static NSString * const kNRAttr_currentView  = @"currentView";
static NSString * const kNRAttr_appeared     = @"appeared";
static NSString * const kNRAttr_reappeared   = @"reappeared";
static NSString * const kNRAttr_loadTime     = @"loadTime";
static NSString * const kNRAttr_component    = @"component";
static NSString * const kNRAttr_componentOf  = @"componentOf";
static NSString * const kNRAttr_timingName   = @"timingName";
static NSString * const kNRAttr_timingValue  = @"timingValue";

/// A non-empty string, or nil. The script's `if row.get(key):` for a string field.
static NSString *NRMANonEmptyString(id value) {
    return ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) ? value : nil;
}

/// Python truthiness for a flag field: a non-zero number or a non-empty string.
static BOOL NRMATruthy(id value) {
    if (value == nil || value == [NSNull null]) return NO;
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value doubleValue] != 0;
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value length] > 0;
    return YES;
}

@implementation NRMASessionFlowGraph {
    NSMutableDictionary<NRMASessionFlowEdgeKey, NSNumber *> *_edgeCounts;
    NSMutableDictionary<NRMASessionFlowEdgeKey, NSNumber *> *_backEdgeCounts;
    NSMutableSet<NSString *> *_nodes;
    NSMutableDictionary<NSString *, NSNumber *> *_loadTimeTotals;
    NSMutableDictionary<NSString *, NSNumber *> *_loadTimeCounts;
    NSMutableDictionary<NSString *, NSNumber *> *_componentLoadTimeTotals;
    NSMutableDictionary<NSString *, NSNumber *> *_componentLoadTimeCounts;
    NSMutableDictionary<NSString *, NSString *> *_componentOwners;
    NSMutableDictionary<NSString *, NSString *> *_drawnComponentOwners;
    NSMutableArray<NSArray *> *_timingSamples;
    NSMutableDictionary<NSArray<NSString *> *, NSNumber *> *_breadcrumbCounts;
    BOOL _truncated;
    BOOL _loggedTruncation;
}

- (instancetype)init {
    if ((self = [super init])) {
        _edgeCounts              = [NSMutableDictionary dictionary];
        _backEdgeCounts          = [NSMutableDictionary dictionary];
        _nodes                   = [NSMutableSet set];
        _loadTimeTotals          = [NSMutableDictionary dictionary];
        _loadTimeCounts          = [NSMutableDictionary dictionary];
        _componentLoadTimeTotals = [NSMutableDictionary dictionary];
        _componentLoadTimeCounts = [NSMutableDictionary dictionary];
        _componentOwners         = [NSMutableDictionary dictionary];
        _drawnComponentOwners    = [NSMutableDictionary dictionary];
        _timingSamples           = [NSMutableArray array];
        _breadcrumbCounts        = [NSMutableDictionary dictionary];
    }
    return self;
}

// A snapshot for rendering. The monitor renders outside its lock, and a live graph mutated by a
// concurrent appearance mid-render would throw out of the enumeration. Values are immutable
// (NSNumber, NSString, NSArray), so copying the containers is a full copy.
- (id)copyWithZone:(NSZone *)zone {
    NRMASessionFlowGraph *copy = [[[self class] allocWithZone:zone] init];
    copy->_edgeCounts              = [_edgeCounts mutableCopy];
    copy->_backEdgeCounts          = [_backEdgeCounts mutableCopy];
    copy->_nodes                   = [_nodes mutableCopy];
    copy->_loadTimeTotals          = [_loadTimeTotals mutableCopy];
    copy->_loadTimeCounts          = [_loadTimeCounts mutableCopy];
    copy->_componentLoadTimeTotals = [_componentLoadTimeTotals mutableCopy];
    copy->_componentLoadTimeCounts = [_componentLoadTimeCounts mutableCopy];
    copy->_componentOwners         = [_componentOwners mutableCopy];
    copy->_drawnComponentOwners    = [_drawnComponentOwners mutableCopy];
    copy->_timingSamples           = [_timingSamples mutableCopy];
    copy->_breadcrumbCounts        = [_breadcrumbCounts mutableCopy];
    copy->_truncated               = _truncated;
    copy->_loggedTruncation        = _loggedTruncation;
    return copy;
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

- (void)recordMobileViewAttributes:(NSDictionary<NSString *, id> *)attributes {
    if (attributes.count == 0) return;

    NSString *viewName = NRMANonEmptyString(attributes[kNRAttr_viewName]);
    BOOL isComponent = NRMATruthy(attributes[kNRAttr_component]);
    NSString *owner = NRMANonEmptyString(attributes[kNRAttr_componentOf]);

    // component_owners(): read from every row, before the appear filter, because a component can be
    // another event's previousView even when its own row is dropped.
    if (viewName != nil && isComponent && owner != nil) {
        _componentOwners[viewName] = owner;
    }

    // appear_events(): a disappear event carries timeVisible, not a transition.
    id appeared = attributes[kNRAttr_appeared];
    if ([appeared isKindOfClass:[NSNumber class]] && ![appeared boolValue]) return;
    if (viewName == nil) return;

    NSString *previousView = NRMANonEmptyString(attributes[kNRAttr_previousView]);
    [self addTransitionFrom:previousView to:viewName isBack:NRMATruthy(attributes[kNRAttr_reappeared])];

    id loadTime = attributes[kNRAttr_loadTime];
    if ([loadTime isKindOfClass:[NSNumber class]]) {
        [self addLoadTime:[loadTime doubleValue] forView:viewName component:isComponent];
    }
    if (isComponent && owner != nil) {
        _drawnComponentOwners[viewName] = owner;
    }
}

- (void)addTransitionFrom:(NSString *)from to:(NSString *)to isBack:(BOOL)isBack {
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

- (void)addLoadTime:(double)milliseconds forView:(NSString *)view component:(BOOL)component {
    // Load samples are only ever read for views the graph already knows, so no separate cap: the
    // node cap already bounds how many keys can appear here.
    if (![_nodes containsObject:view]) return;
    NSMutableDictionary<NSString *, NSNumber *> *totals = component ? _componentLoadTimeTotals : _loadTimeTotals;
    NSMutableDictionary<NSString *, NSNumber *> *counts = component ? _componentLoadTimeCounts : _loadTimeCounts;
    totals[view] = @(totals[view].doubleValue + milliseconds);
    counts[view] = @(counts[view].unsignedIntegerValue + 1);
}

- (void)recordViewTimingAttributes:(NSDictionary<NSString *, id> *)attributes {
    NSString *viewName = NRMANonEmptyString(attributes[kNRAttr_viewName]);
    NSString *timingName = NRMANonEmptyString(attributes[kNRAttr_timingName]);
    id value = attributes[kNRAttr_timingValue];
    // A timing recorded with no view current has nothing on the diagram to attach to.
    if (viewName == nil || timingName == nil || ![value isKindOfClass:[NSNumber class]]) return;
    if (_timingSamples.count >= NRMASessionFlowMaxTimingSamples) {
        [self markTruncated:@"timing"];
        return;
    }
    NSString *previousView = NRMANonEmptyString(attributes[kNRAttr_previousView]);
    [_timingSamples addObject:@[viewName, previousView ?: (id)[NSNull null], timingName, value]];
}

- (void)recordBreadcrumbNamed:(NSString *)name attributes:(NSDictionary<NSString *, id> *)attributes {
    if (NRMANonEmptyString(name) == nil) return;
    NSString *view = NRMANonEmptyString(attributes[kNRAttr_currentView]);
    if (view == nil) return;
    NSArray<NSString *> *key = @[view, name];
    if (_breadcrumbCounts[key] == nil && _breadcrumbCounts.count >= NRMASessionFlowMaxBreadcrumbs) {
        [self markTruncated:@"breadcrumb"];
        return;
    }
    _breadcrumbCounts[key] = @(_breadcrumbCounts[key].unsignedIntegerValue + 1);
}

#pragma mark - Read

- (NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *)edgeCounts          { return _edgeCounts; }
- (NSDictionary<NRMASessionFlowEdgeKey, NSNumber *> *)backEdgeCounts      { return _backEdgeCounts; }
- (NSSet<NSString *> *)nodes                                             { return _nodes; }
- (NSDictionary<NSString *, NSNumber *> *)loadTimeTotals                  { return _loadTimeTotals; }
- (NSDictionary<NSString *, NSNumber *> *)loadTimeCounts                  { return _loadTimeCounts; }
- (NSDictionary<NSString *, NSNumber *> *)componentLoadTimeTotals         { return _componentLoadTimeTotals; }
- (NSDictionary<NSString *, NSNumber *> *)componentLoadTimeCounts         { return _componentLoadTimeCounts; }
- (NSDictionary<NSString *, NSString *> *)componentOwners                 { return _componentOwners; }
- (NSDictionary<NSString *, NSString *> *)drawnComponentOwners            { return _drawnComponentOwners; }
- (NSArray<NSArray *> *)timingSamples                                     { return _timingSamples; }
- (NSDictionary<NSArray<NSString *> *, NSNumber *> *)breadcrumbCounts     { return _breadcrumbCounts; }
- (BOOL)truncated                                                        { return _truncated; }

- (BOOL)isEmpty {
    return _edgeCounts.count == 0 && _nodes.count == 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %lu screens, %lu transitions, %lu timings, %lu breadcrumbs%@>",
            NSStringFromClass([self class]), (unsigned long)_nodes.count,
            (unsigned long)_edgeCounts.count, (unsigned long)_timingSamples.count,
            (unsigned long)_breadcrumbCounts.count, _truncated ? @", truncated" : @""];
}

@end
