//
//  NRMASessionFlowMonitor.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionFlowMonitor.h"
#import "NRMASessionFlowRenderer.h"
#import "NewRelicAgentInternal.h"
#import <os/lock.h>

const NSUInteger NRMASessionFlowArchiveLimit = 5;

// MobileView / MobileBreadcrumb attribute keys this reads. Same schema as NRMAMobileViewTracker and
// NRMAViewContext emit, and as scripts/mobileview_flow.py consumes.
static NSString * const kNRAttr_viewName     = @"viewName";
static NSString * const kNRAttr_previousView = @"previousView";
static NSString * const kNRAttr_currentView  = @"currentView";
static NSString * const kNRAttr_appeared     = @"appeared";
static NSString * const kNRAttr_reappeared   = @"reappeared";
static NSString * const kNRAttr_loadTime     = @"loadTime";
static NSString * const kNRAttr_component    = @"component";
static NSString * const kNRAttr_componentOf  = @"componentOf";

/// One finished session's diagram.
@interface NRMASessionFlowArchiveEntry : NSObject
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, strong) NRMASessionFlowGraph *graph;
@end

@implementation NRMASessionFlowArchiveEntry
@end

@implementation NRMASessionFlowMonitor {
    os_unfair_lock _lock;
    NRMASessionFlowGraph *_liveGraph;
    /// The session the live graph belongs to, captured on first ingest. Held rather than re-read so
    /// finalize can archive under the *ending* session's id without calling out mid-teardown.
    NSString *_liveSessionId;
    NSMutableArray<NRMASessionFlowArchiveEntry *> *_archive;  // oldest first
}

+ (instancetype)sharedInstance {
    static NRMASessionFlowMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NRMASessionFlowMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _liveGraph = [[NRMASessionFlowGraph alloc] init];
        _archive = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Session identity

// Archives the live graph and starts an empty one. Caller holds _lock.
- (void)archiveLiveGraphLocked {
    if (!_liveGraph.isEmpty) {
        NRMASessionFlowArchiveEntry *entry = [[NRMASessionFlowArchiveEntry alloc] init];
        entry.sessionId = _liveSessionId ?: @"";
        entry.graph = _liveGraph;
        [_archive addObject:entry];
        while (_archive.count > NRMASessionFlowArchiveLimit) {
            [_archive removeObjectAtIndex:0];
        }
    }
    _liveGraph = [[NRMASessionFlowGraph alloc] init];
    _liveSessionId = nil;
}

// Binds the live graph to `sessionId`, rolling it first if the agent has moved on to a new session
// without the session-end tap having fired. Caller holds _lock.
//
// The tap is the normal path; this is the backstop for a session that rolls some other way (an
// explicit +[NewRelic startNewSession], say). Without it a new session's screens would keep landing
// in the previous session's diagram.
- (void)bindLiveGraphToSessionLocked:(NSString *)sessionId {
    if (sessionId.length == 0) return;
    if (_liveSessionId == nil) {
        _liveSessionId = [sessionId copy];
    } else if (![_liveSessionId isEqualToString:sessionId]) {
        [self archiveLiveGraphLocked];
        _liveSessionId = [sessionId copy];
    }
}

#pragma mark - Ingest

- (void)recordMobileViewEventWithAttributes:(NSDictionary<NSString *, id> *)attributes {
    if (attributes.count == 0) return;

    // Only appear events describe a transition: they are the ones carrying previousView. Disappear
    // events carry timeVisible and are the other half of the same screen's lifetime.
    id appeared = attributes[kNRAttr_appeared];
    if (appeared != nil && ![appeared boolValue]) return;

    NSString *viewName = attributes[kNRAttr_viewName];
    if (![viewName isKindOfClass:[NSString class]] || viewName.length == 0) return;

    NSString *previousView = attributes[kNRAttr_previousView];
    if (![previousView isKindOfClass:[NSString class]] || previousView.length == 0) {
        previousView = nil;  // first screen of the session — renders from the start node
    }

    BOOL isBack = [attributes[kNRAttr_reappeared] boolValue];

    NSString *componentOf = attributes[kNRAttr_componentOf];
    BOOL isComponent = [attributes[kNRAttr_component] boolValue]
                       && [componentOf isKindOfClass:[NSString class]]
                       && ((NSString *)componentOf).length > 0;

    id loadTime = attributes[kNRAttr_loadTime];
    BOOL hasLoadTime = [loadTime isKindOfClass:[NSNumber class]];

    // Read outside the lock: currentSessionId is a plain property read, but keeping every call-out
    // off the locked region is the rule this file follows.
    NSString *sessionId = [[NewRelicAgentInternal sharedInstance] currentSessionId];

    os_unfair_lock_lock(&_lock);
    [self bindLiveGraphToSessionLocked:sessionId];
    [_liveGraph addTransitionFrom:previousView to:viewName isBack:isBack];
    if (isComponent) {
        [_liveGraph noteView:viewName asComponentOfScreen:componentOf];
    }
    if (hasLoadTime) {
        [_liveGraph addLoadTimeMilliseconds:[loadTime doubleValue] forView:viewName];
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)recordBreadcrumbNamed:(NSString *)name attributes:(NSDictionary<NSString *, id> *)attributes {
    if (name.length == 0) return;
    NSString *currentView = attributes[kNRAttr_currentView];
    // No currentView means the breadcrumb predates any view appearing, so there is no screen to
    // attach it to.
    if (![currentView isKindOfClass:[NSString class]] || currentView.length == 0) return;

    NSString *sessionId = [[NewRelicAgentInternal sharedInstance] currentSessionId];

    os_unfair_lock_lock(&_lock);
    [self bindLiveGraphToSessionLocked:sessionId];
    [_liveGraph addBreadcrumbNamed:name forView:currentView];
    os_unfair_lock_unlock(&_lock);
}

#pragma mark - Session lifecycle

- (void)finalizeCurrentSessionDiagram {
    os_unfair_lock_lock(&_lock);
    [self archiveLiveGraphLocked];
    os_unfair_lock_unlock(&_lock);
}

#pragma mark - Diagrams

- (NSString *)mermaidForCurrentSessionWithOptions:(NRSessionFlowDiagramOptions *)options {
    os_unfair_lock_lock(&_lock);
    NRMASessionFlowGraph *graph = _liveGraph;
    os_unfair_lock_unlock(&_lock);
    // Rendered outside the lock. The graph can still be mutated by a concurrent appearance while
    // this runs, which at worst renders a diagram missing the screen that appeared a moment ago —
    // the same staleness any snapshot of a live session has.
    return [NRMASessionFlowRenderer mermaidForGraph:graph options:options];
}

- (NSArray<NSString *> *)archivedSessionIds {
    os_unfair_lock_lock(&_lock);
    NSMutableArray<NSString *> *ids = [NSMutableArray arrayWithCapacity:_archive.count];
    for (NRMASessionFlowArchiveEntry *entry in _archive) {
        [ids addObject:entry.sessionId];
    }
    os_unfair_lock_unlock(&_lock);
    return ids;
}

- (NSString *)mermaidForSessionId:(NSString *)sessionId options:(NRSessionFlowDiagramOptions *)options {
    if (sessionId.length == 0) return nil;
    os_unfair_lock_lock(&_lock);
    NRMASessionFlowGraph *graph = nil;
    // Newest wins: a session id could in principle be archived twice if the graph was rolled by the
    // backstop and then again by the session-end tap.
    for (NRMASessionFlowArchiveEntry *entry in _archive.reverseObjectEnumerator) {
        if ([entry.sessionId isEqualToString:sessionId]) { graph = entry.graph; break; }
    }
    os_unfair_lock_unlock(&_lock);
    if (graph == nil) return nil;
    return [NRMASessionFlowRenderer mermaidForGraph:graph options:options];
}

- (NSString *)currentSessionSummary {
    os_unfair_lock_lock(&_lock);
    NRMASessionFlowGraph *graph = _liveGraph;
    NSString *sessionId = _liveSessionId;
    NSUInteger archived = _archive.count;
    os_unfair_lock_unlock(&_lock);
    return [NSString stringWithFormat:
            @"session %@ — %lu screens, %lu transitions, %lu breadcrumbs%@ (%lu archived)",
            sessionId.length > 0 ? sessionId : @"(none)",
            (unsigned long)graph.nodes.count,
            (unsigned long)graph.edgeCounts.count,
            (unsigned long)graph.breadcrumbCounts.count,
            graph.truncated ? @", truncated" : @"",
            (unsigned long)archived];
}

- (void)reset {
    os_unfair_lock_lock(&_lock);
    _liveGraph = [[NRMASessionFlowGraph alloc] init];
    _liveSessionId = nil;
    [_archive removeAllObjects];
    os_unfair_lock_unlock(&_lock);
}

@end
