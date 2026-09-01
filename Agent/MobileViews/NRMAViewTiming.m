//
//  NRMAViewTiming.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAViewTiming.h"
#import "NRMAViewContext.h"
#import "NRMAFlags.h"
#import "NewRelic.h"
#import "NRLogger.h"
#import <os/lock.h>

NSString * const kNRMAViewTimingEventType     = @"MobileViewTiming";
NSString * const kNRMAViewTimingInitialDisplay = @"timeToInitialDisplay";

const NSUInteger kNRMAViewTimingMaxPerViewInstance = 16;
const NSUInteger kNRMAViewTimingMaxNameLength      = 128;
const double     kNRMAViewTimingMaxMilliseconds    = 10 * 60 * 1000;   // 10 minutes

// Attribute keys. Kept as literals here rather than shared with NRMAViewContext because this is a
// different event type: viewName/viewInstanceId mean the same thing, but timingName/timingValue are
// this schema's own and the two schemas are free to diverge.
static NSString * const kNRAttr_timingName     = @"timingName";
static NSString * const kNRAttr_timingValue    = @"timingValue";
static NSString * const kNRAttr_viewName       = @"viewName";
static NSString * const kNRAttr_viewInstanceId = @"viewInstanceId";
static NSString * const kNRAttr_previousView   = @"previousView";
static NSString * const kNRAttr_uiPlatform     = @"uiPlatform";
static NSString * const kNRAttr_agentName      = @"agentName";
static NSString * const kNRAgentName           = @"iOS";

// Cap bucket for timings recorded with no view current. A view instance's bucket is naturally
// bounded — the view goes away — but this one is not, so it is rate limited by window instead of
// capped for the process lifetime. Without the window, sixteen unattributed timings early in a
// launch would silence the path for good.
static NSString * const kNRUnattributedBucket   = @"__nrma_unattributed__";
static const CFTimeInterval kNRUnattributedWindowSeconds = 60.0;

// Upper bound on tracked buckets. Every visited view instance would otherwise be remembered for the
// life of the process. Oldest-inserted buckets are evicted first: they belong to views the user has
// long since left, so re-admitting them to the cap costs nothing real.
static const NSUInteger kNRMaxTrackedBuckets = 64;

/// Mutable count for one bucket, plus when its window opened (used only by the unattributed bucket).
@interface NRMAViewTimingBucket : NSObject
@property (nonatomic) NSUInteger count;
@property (nonatomic) CFAbsoluteTime windowStart;
@end

@implementation NRMAViewTimingBucket
@end

@implementation NRMAViewTimingSnapshot

- (instancetype)initWithViewName:(NSString *)viewName
                  viewInstanceId:(NSString *)viewInstanceId
                    previousView:(NSString *)previousView
                      uiPlatform:(NSString *)uiPlatform
                      appearTime:(CFAbsoluteTime)appearTime
                  hasCurrentView:(BOOL)hasCurrentView {
    if ((self = [super init])) {
        _viewName       = [viewName copy];
        _viewInstanceId = [viewInstanceId copy];
        _previousView   = [previousView copy];
        _uiPlatform     = [uiPlatform copy];
        _appearTime     = appearTime;
        _hasCurrentView = hasCurrentView;
    }
    return self;
}

@end

@implementation NRMAViewTiming {
    os_unfair_lock _lock;                                            // guards the two below
    NSMutableDictionary<NSString *, NRMAViewTimingBucket *> *_buckets;
    NSMutableArray<NSString *> *_bucketOrder;                        // insertion order, for eviction
    BOOL _warnedAboutCap;
}

+ (instancetype)sharedInstance {
    static NRMAViewTiming *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NRMAViewTiming alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lock        = OS_UNFAIR_LOCK_INIT;
        _buckets     = [NSMutableDictionary dictionary];
        _bucketOrder = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Gate

// Timing rides the MobileViews flags rather than introducing a flag of its own: a timing with no
// view to attach to is not useful, and this is the same condition recordBreadcrumb: uses to decide
// whether to stamp referrer attributes.
- (BOOL)isEnabled {
    return [NRMAFlags shouldEnableAutomaticMobileViews] || [NRMAFlags shouldEnableManualMobileViews];
}

#pragma mark - Public API entry points

- (BOOL)markTimingNamed:(NSString *)name {
    if (![self isEnabled]) { return NO; }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NRMAViewTimingSnapshot *snapshot = [[NRMAViewContext sharedInstance] snapshotForTiming];

    // No current view means no zero point. Emitting a duration measured from an unknown start is
    // worse than emitting nothing, because it looks like real data in an aggregate.
    if (!snapshot.hasCurrentView) {
        NRLOG_AGENT_WARNING(@"markViewTiming:\"%@\" ignored: no view is currently being tracked. "
                            @"Use recordViewTiming:milliseconds: to supply the duration yourself.", name);
        return NO;
    }

    double milliseconds = [NRMAViewContext millisecondsBetween:snapshot.appearTime and:now];
    return [self emitTimingNamed:name milliseconds:milliseconds snapshot:snapshot agentOwned:NO];
}

- (BOOL)recordTimingNamed:(NSString *)name milliseconds:(double)milliseconds {
    if (![self isEnabled]) { return NO; }

    NRMAViewTimingSnapshot *snapshot = [[NRMAViewContext sharedInstance] snapshotForTiming];
    return [self emitTimingNamed:name milliseconds:milliseconds snapshot:snapshot agentOwned:NO];
}

#pragma mark - Agent-owned emission

- (void)recordInitialDisplayForViewNamed:(NSString *)viewName
                              instanceId:(NSString *)instanceId
                            previousView:(NSString *)previousView
                                platform:(NSString *)platform
                            milliseconds:(double)milliseconds {
    if (![self isEnabled]) { return; }
    if (viewName.length == 0) { return; }

    NRMAViewTimingSnapshot *snapshot =
        [[NRMAViewTimingSnapshot alloc] initWithViewName:viewName
                                         viewInstanceId:instanceId
                                           previousView:previousView
                                             uiPlatform:platform
                                             appearTime:0
                                         hasCurrentView:YES];

    [self emitTimingNamed:kNRMAViewTimingInitialDisplay
             milliseconds:milliseconds
                 snapshot:snapshot
               agentOwned:YES];
}

#pragma mark - Emission

- (BOOL)emitTimingNamed:(NSString *)name
           milliseconds:(double)milliseconds
               snapshot:(NRMAViewTimingSnapshot *)snapshot
             agentOwned:(BOOL)agentOwned {
    NSDictionary<NSString *, id> *attrs = [self attributesForTimingNamed:name
                                                           milliseconds:milliseconds
                                                               snapshot:snapshot
                                                             agentOwned:agentOwned];
    if (attrs == nil) { return NO; }

    return [NewRelic recordCustomEvent:kNRMAViewTimingEventType attributes:attrs];
}

#pragma mark - Decision layer

- (NSDictionary<NSString *, id> *)attributesForTimingNamed:(NSString *)name
                                             milliseconds:(double)milliseconds
                                                 snapshot:(NRMAViewTimingSnapshot *)snapshot
                                               agentOwned:(BOOL)agentOwned {
    if (![self isValidName:name agentOwned:agentOwned]) { return nil; }
    if (![self isValidDuration:milliseconds name:name])  { return nil; }

    // Agent-owned rows bypass the cap: a customer marking in a loop must not be able to suppress
    // the out-of-the-box baseline.
    if (!agentOwned && ![self admitTimingForSnapshot:snapshot]) { return nil; }

    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    attrs[kNRAttr_timingName]  = name;
    attrs[kNRAttr_timingValue] = @(milliseconds);
    attrs[kNRAttr_agentName]   = kNRAgentName;

    // Only keys with values are set; an absent view must read as absent, not as an empty string.
    if (snapshot.viewName.length > 0)       { attrs[kNRAttr_viewName]       = snapshot.viewName; }
    if (snapshot.viewInstanceId.length > 0) { attrs[kNRAttr_viewInstanceId] = snapshot.viewInstanceId; }
    if (snapshot.previousView.length > 0)   { attrs[kNRAttr_previousView]   = snapshot.previousView; }
    if (snapshot.uiPlatform.length > 0)     { attrs[kNRAttr_uiPlatform]     = snapshot.uiPlatform; }

    return attrs;
}

#pragma mark - Validation

- (BOOL)isValidName:(NSString *)name agentOwned:(BOOL)agentOwned {
    if (name.length == 0) {
        NRLOG_AGENT_WARNING(@"View timing ignored: name must not be empty.");
        return NO;
    }
    if (name.length > kNRMAViewTimingMaxNameLength) {
        NRLOG_AGENT_WARNING(@"View timing \"%@\" ignored: name exceeds %lu characters.",
                            name, (unsigned long)kNRMAViewTimingMaxNameLength);
        return NO;
    }
    if (!agentOwned && [name isEqualToString:kNRMAViewTimingInitialDisplay]) {
        NRLOG_AGENT_WARNING(@"View timing \"%@\" ignored: that name is recorded by the agent and is "
                            @"reserved. Choose another name.", name);
        return NO;
    }
    return YES;
}

- (BOOL)isValidDuration:(double)milliseconds name:(NSString *)name {
    // isnan/isinf first: a NaN reaching NRDB silently poisons every average() and percentile()
    // computed over this event type, and comparisons against NaN are all false so a range check
    // alone would let it through.
    if (isnan(milliseconds) || isinf(milliseconds)) {
        NRLOG_AGENT_WARNING(@"View timing \"%@\" ignored: duration is not a finite number.", name);
        return NO;
    }
    if (milliseconds < 0) {
        NRLOG_AGENT_WARNING(@"View timing \"%@\" ignored: duration %.1f is negative.", name, milliseconds);
        return NO;
    }
    if (milliseconds > kNRMAViewTimingMaxMilliseconds) {
        NRLOG_AGENT_WARNING(@"View timing \"%@\" ignored: duration %.1fms exceeds the %.0fms limit. "
                            @"Durations are milliseconds, not seconds.",
                            name, milliseconds, kNRMAViewTimingMaxMilliseconds);
        return NO;
    }
    return YES;
}

#pragma mark - Capping

/// Returns whether this timing is within its bucket's cap, counting it if so.
- (BOOL)admitTimingForSnapshot:(NRMAViewTimingSnapshot *)snapshot {
    BOOL isUnattributed = (snapshot.viewInstanceId.length == 0);
    NSString *key = isUnattributed ? kNRUnattributedBucket : snapshot.viewInstanceId;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

    BOOL admitted = NO;
    BOOL shouldWarn = NO;

    os_unfair_lock_lock(&_lock);
    NRMAViewTimingBucket *bucket = _buckets[key];
    if (bucket == nil) {
        bucket = [[NRMAViewTimingBucket alloc] init];
        bucket.windowStart = now;
        _buckets[key] = bucket;
        [_bucketOrder addObject:key];

        // Evict oldest-inserted buckets so a long session cannot accumulate one per visited view.
        while (_bucketOrder.count > kNRMaxTrackedBuckets) {
            NSString *oldest = _bucketOrder.firstObject;
            [_bucketOrder removeObjectAtIndex:0];
            [_buckets removeObjectForKey:oldest];
        }
    } else if (isUnattributed && (now - bucket.windowStart) > kNRUnattributedWindowSeconds) {
        // Rate limit rather than a lifetime cap: see kNRUnattributedBucket.
        bucket.count = 0;
        bucket.windowStart = now;
    }

    if (bucket.count < kNRMAViewTimingMaxPerViewInstance) {
        bucket.count += 1;
        admitted = YES;
    } else if (!_warnedAboutCap) {
        _warnedAboutCap = YES;
        shouldWarn = YES;
    }
    os_unfair_lock_unlock(&_lock);

    // Logged outside the lock: NRLogger can take locks of its own, and this one is non-recursive.
    if (shouldWarn) {
        NRLOG_AGENT_WARNING(@"View timing dropped: more than %lu timings recorded for a single view. "
                            @"Later timings for this view are ignored. Are you calling "
                            @"markViewTiming: from a cell or a loop?",
                            (unsigned long)kNRMAViewTimingMaxPerViewInstance);
    }
    return admitted;
}

@end
