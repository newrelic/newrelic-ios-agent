//
//  NRMASessionFlowMonitor.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionFlowMonitor.h"
#import "NRMASessionFlowGraph.h"
#import "NRMASessionTimeline.h"
#import "NRMASessionFlowRenderer.h"
#import "NewRelicAgentInternal.h"
#import "Constants.h"
#import <os/lock.h>

const NSUInteger NRMASessionFlowArchiveLimit = 5;

/// One session's data. Archived as a unit, so a session's flow and timeline always agree.
@interface NRMASessionFlowRecord : NSObject <NSCopying>
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, strong) NRMASessionFlowGraph *graph;
@property (nonatomic, strong) NRMASessionTimeline *timeline;
@end

@implementation NRMASessionFlowRecord

- (instancetype)init {
    if ((self = [super init])) {
        _sessionId = @"";
        _graph = [[NRMASessionFlowGraph alloc] init];
        _timeline = [[NRMASessionTimeline alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    NRMASessionFlowRecord *copy = [[[self class] allocWithZone:zone] init];
    copy.sessionId = _sessionId;
    copy.graph = [_graph copy];
    copy.timeline = [_timeline copy];
    return copy;
}

- (BOOL)isEmpty {
    return _graph.isEmpty && _timeline.isEmpty;
}

@end

@implementation NRMASessionFlowMonitor {
    os_unfair_lock _lock;
    NRMASessionFlowRecord *_live;
    /// Whether _live has been bound to a session id yet. Held rather than re-read so finalize can
    /// archive under the *ending* session's id without calling out mid-teardown.
    BOOL _liveBound;
    NSMutableArray<NRMASessionFlowRecord *> *_archive;  // oldest first
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
        _live = [[NRMASessionFlowRecord alloc] init];
        _archive = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Session identity

// Archives the live record and starts an empty one. Caller holds _lock.
- (void)archiveLiveLocked {
    if (!_live.isEmpty) {
        [_archive addObject:_live];
        while (_archive.count > NRMASessionFlowArchiveLimit) {
            [_archive removeObjectAtIndex:0];
        }
    }
    _live = [[NRMASessionFlowRecord alloc] init];
    _liveBound = NO;
}

// Binds the live record to `sessionId`, rolling it first if the agent has moved on to a new session
// without the session-end tap having fired. Caller holds _lock.
//
// The tap is the normal path; this is the backstop for a session that rolls some other way (an
// explicit +[NewRelic startNewSession], say). Without it a new session's screens would keep landing
// in the previous session's diagram.
- (void)bindLiveToSessionLocked:(NSString *)sessionId {
    if (sessionId.length == 0) return;
    if (!_liveBound) {
        _live.sessionId = sessionId;
        _liveBound = YES;
    } else if (![_live.sessionId isEqualToString:sessionId]) {
        [self archiveLiveLocked];
        _live.sessionId = sessionId;
        _liveBound = YES;
    }
}

#pragma mark - Ingest

- (void)recordViewEventOfType:(NSString *)eventType
                   attributes:(NSDictionary<NSString *, id> *)attributes
                    timestamp:(double)timestamp
        sessionElapsedSeconds:(double)sessionElapsedSeconds {
    if (attributes.count == 0) return;
    BOOL isView = [eventType isEqualToString:kNRMA_RET_mobileView];
    BOOL isTiming = !isView && [eventType isEqualToString:kNRMA_RET_mobileViewTiming];
    if (!isView && !isTiming) return;

    // Read outside the lock: currentSessionId is a plain property read, but keeping every call-out
    // off the locked region is the rule this file follows.
    NSString *sessionId = [[NewRelicAgentInternal sharedInstance] currentSessionId];

    os_unfair_lock_lock(&_lock);
    [self bindLiveToSessionLocked:sessionId];
    if (isView) {
        [_live.graph recordMobileViewAttributes:attributes];
        [_live.timeline recordMobileViewAttributes:attributes timestamp:timestamp
                             sessionElapsedSeconds:sessionElapsedSeconds];
    } else {
        [_live.graph recordViewTimingAttributes:attributes];
        [_live.timeline recordViewTimingAttributes:attributes timestamp:timestamp
                             sessionElapsedSeconds:sessionElapsedSeconds];
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)recordBreadcrumbNamed:(NSString *)name attributes:(NSDictionary<NSString *, id> *)attributes {
    if (name.length == 0) return;
    NSString *sessionId = [[NewRelicAgentInternal sharedInstance] currentSessionId];

    os_unfair_lock_lock(&_lock);
    [self bindLiveToSessionLocked:sessionId];
    [_live.graph recordBreadcrumbNamed:name attributes:attributes];
    os_unfair_lock_unlock(&_lock);
}

#pragma mark - Session lifecycle

- (void)finalizeCurrentSessionDiagram {
    os_unfair_lock_lock(&_lock);
    [self archiveLiveLocked];
    os_unfair_lock_unlock(&_lock);
}

#pragma mark - Diagrams

// A copy of the live record, taken under the lock. Rendering walks every container in the graph,
// and a concurrent appearance mutating one mid-walk would throw out of the enumeration, so the
// renderer only ever sees a snapshot. Archived records are never mutated again and need no copy.
- (NRMASessionFlowRecord *)liveSnapshot {
    os_unfair_lock_lock(&_lock);
    NRMASessionFlowRecord *snapshot = [_live copy];
    os_unfair_lock_unlock(&_lock);
    return snapshot;
}

- (NRMASessionFlowRecord *)archivedRecordForSessionId:(NSString *)sessionId {
    if (sessionId.length == 0) return nil;
    os_unfair_lock_lock(&_lock);
    NRMASessionFlowRecord *record = nil;
    // Newest wins: a session id could in principle be archived twice if the record was rolled by the
    // backstop and then again by the session-end tap.
    for (NRMASessionFlowRecord *entry in _archive.reverseObjectEnumerator) {
        if ([entry.sessionId isEqualToString:sessionId]) { record = entry; break; }
    }
    os_unfair_lock_unlock(&_lock);
    return record;
}

- (NSString *)mermaidForCurrentSessionWithOptions:(NRSessionFlowDiagramOptions *)options {
    return [NRMASessionFlowRenderer mermaidForGraph:[self liveSnapshot].graph options:options];
}

- (NSString *)timelineForCurrentSessionWithOptions:(NRSessionFlowDiagramOptions *)options {
    return [NRMASessionFlowRenderer timelineMermaidForTimeline:[self liveSnapshot].timeline options:options];
}

- (NSArray<NSString *> *)archivedSessionIds {
    os_unfair_lock_lock(&_lock);
    NSMutableArray<NSString *> *ids = [NSMutableArray arrayWithCapacity:_archive.count];
    for (NRMASessionFlowRecord *entry in _archive) {
        [ids addObject:entry.sessionId];
    }
    os_unfair_lock_unlock(&_lock);
    return ids;
}

- (NSString *)mermaidForSessionId:(NSString *)sessionId options:(NRSessionFlowDiagramOptions *)options {
    NRMASessionFlowRecord *record = [self archivedRecordForSessionId:sessionId];
    return record ? [NRMASessionFlowRenderer mermaidForGraph:record.graph options:options] : nil;
}

- (NSString *)timelineForSessionId:(NSString *)sessionId options:(NRSessionFlowDiagramOptions *)options {
    NRMASessionFlowRecord *record = [self archivedRecordForSessionId:sessionId];
    return record ? [NRMASessionFlowRenderer timelineMermaidForTimeline:record.timeline options:options] : nil;
}

- (NSString *)currentSessionSummary {
    NRMASessionFlowRecord *live = [self liveSnapshot];
    os_unfair_lock_lock(&_lock);
    NSUInteger archived = _archive.count;
    os_unfair_lock_unlock(&_lock);
    NRMASessionFlowGraph *graph = live.graph;
    return [NSString stringWithFormat:
            @"session %@ — %lu screens, %lu transitions, %lu timings, %lu breadcrumbs%@ (%lu archived)",
            live.sessionId.length > 0 ? live.sessionId : @"(none)",
            (unsigned long)graph.nodes.count,
            (unsigned long)graph.edgeCounts.count,
            (unsigned long)graph.timingSamples.count,
            (unsigned long)graph.breadcrumbCounts.count,
            (graph.truncated || live.timeline.truncated) ? @", truncated" : @"",
            (unsigned long)archived];
}

- (void)reset {
    os_unfair_lock_lock(&_lock);
    _live = [[NRMASessionFlowRecord alloc] init];
    _liveBound = NO;
    [_archive removeAllObjects];
    os_unfair_lock_unlock(&_lock);
}

@end
