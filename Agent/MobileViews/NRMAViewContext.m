//
//  NRMAViewContext.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAViewContext.h"
#import <os/lock.h>
#import "NewRelic.h"
#import "NRMAViewTiming.h"
#import "Constants.h"
#import "NRMAFlags.h"

// MobileView event type + attribute keys (shared schema with NRMAMobileViewTracker).
static NSString * const kNRMobileViewEventType = @"MobileView";
static NSString * const kNRAttr_viewClass      = @"viewClass";
static NSString * const kNRAttr_viewName       = @"viewName";
static NSString * const kNRAttr_viewInstanceId = @"viewInstanceId";
static NSString * const kNRAttr_previousView   = @"previousView";
static NSString * const kNRAttr_previousViewId = @"previousViewInstanceId";
static NSString * const kNRAttr_currentView    = @"currentView";
static NSString * const kNRAttr_currentViewId  = @"currentViewInstanceId";
static NSString * const kNRAttr_timeVisible    = @"timeVisible";
static NSString * const kNRAttr_appeared       = @"appeared";
static NSString * const kNRAttr_uiPlatform     = @"uiPlatform";
static NSString * const kNRAttr_agentName      = @"agentName";
NSString * const kNRMAAttributeReappeared      = @"reappeared";

// Upper bound on the visible-view stack. A producer can miss a disappearance (a view deallocated
// without SwiftUI calling onDisappear, or the agent starting mid-session), and an unbounded stack
// would then grow for the life of the session and resurface long-dead screens. Oldest entries are
// discarded first; they are the least likely to be what the user is looking at.
static const NSUInteger kNRMAMaxVisibleViews = 32;

// Shortest visible lifetime treated as a real appearance. Below it, the appear/disappear pair is
// construction churn rather than something the user saw.
//
// SwiftUI's TabView is the observed case: switching tabs delivers onAppear for the incoming content,
// then onDisappear for that same content 8-16ms later, then onAppear again with a new identity. The
// middle disappearance is not a navigation, but it *is* the top of the stack going away, so without
// this guard it synthesizes a re-appearance of the previous tab -- a back-navigation the user never
// performed, recorded every single time they switch tabs.
const double kNRMAMinDwellMs = 100.0;

static NSString * const kNRUIPlatformManual    = @"Manual";
static NSString * const kNRAgentName           = @"iOS";

/// One view believed to be on screen. Held oldest-first, so the last element is the topmost.
@interface NRMAVisibleView : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *instanceId;
@property (nonatomic, copy, nullable) NSString *platform;
@property (nonatomic) CFAbsoluteTime appearTime;
@end

@implementation NRMAVisibleView
@end

typedef NS_ENUM(NSUInteger, NRMAViewSource) {
    NRMAViewSourceNone = 0,
    NRMAViewSourceAutomatic,
    NRMAViewSourceManual,
};

@implementation NRMAViewContext {
    os_unfair_lock _lock;

    NSString *_currentViewName;
    NSString *_currentViewInstanceId;
    CFAbsoluteTime _currentViewAppearTime;
    NRMAViewSource _currentViewSource;

    NSString *_previousViewName;
    NSString *_previousViewInstanceId;

    // Views the automatic producers have reported as appeared and not yet as disappeared, oldest
    // first. Only used to decide whether a disappearance uncovered something; _currentViewName
    // above remains the source of truth for referrer stamping.
    NSMutableArray<NRMAVisibleView *> *_visibleViews;
}

+ (instancetype)sharedInstance {
    static NRMAViewContext *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NRMAViewContext alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _currentViewSource = NRMAViewSourceNone;
        _visibleViews = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Automatic producers

- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime {
    [self transitionToView:name instanceId:instanceId appearTime:appearTime platform:nil];
}

- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime
                platform:(nullable NSString *)platform {
    if (name.length == 0) { return; }
    os_unfair_lock_lock(&_lock);
    // A view replacing itself (a new instance of the same screen, as SwiftUI produces during tab
    // churn) keeps the referrer it already had. Shifting it here would make the screen its own
    // previousView, which reads as a navigation from a screen to itself.
    if (![_currentViewName isEqualToString:name]) {
        _previousViewName       = _currentViewName;
        _previousViewInstanceId = _currentViewInstanceId;
    }
    _currentViewName        = [name copy];
    _currentViewInstanceId  = [instanceId copy];
    _currentViewAppearTime  = appearTime;
    _currentViewSource      = NRMAViewSourceAutomatic;
    [self pushVisibleViewLocked:name instanceId:instanceId appearTime:appearTime platform:platform];
    os_unfair_lock_unlock(&_lock);
    [self persistCurrentReferrerState];
}

#pragma mark - Visible-view stack (lock held)

- (void)pushVisibleViewLocked:(NSString *)name
                   instanceId:(NSString *)instanceId
                   appearTime:(CFAbsoluteTime)appearTime
                     platform:(nullable NSString *)platform {
    if (instanceId.length == 0) { return; }

    // A repeated appearance of the same instance replaces the existing entry instead of stacking a
    // duplicate that could later resurface itself.
    [self removeVisibleViewLocked:instanceId];

    NRMAVisibleView *entry = [[NRMAVisibleView alloc] init];
    entry.name       = name;
    entry.instanceId = instanceId;
    entry.platform   = platform;
    entry.appearTime = appearTime;
    [_visibleViews addObject:entry];

    while (_visibleViews.count > kNRMAMaxVisibleViews) {
        [_visibleViews removeObjectAtIndex:0];
    }
}

/// Removes the entry for `instanceId` wherever it sits. Returns NSNotFound if it was not tracked,
/// otherwise the index it occupied, so the caller can tell whether the top changed.
- (NSUInteger)removeVisibleViewLocked:(NSString *)instanceId {
    if (instanceId.length == 0) { return NSNotFound; }
    for (NSUInteger i = 0; i < _visibleViews.count; i++) {
        if ([_visibleViews[i].instanceId isEqualToString:instanceId]) {
            [_visibleViews removeObjectAtIndex:i];
            return i;
        }
    }
    return NSNotFound;
}

#pragma mark - Re-appearance synthesis

- (void)viewDidDisappearNamed:(NSString *)name instanceId:(NSString *)instanceId {
    if (instanceId.length == 0) { return; }

    // Everything the synthesized event needs is captured under the lock and the event is recorded
    // after releasing it: -recordCustomEvent: runs the analytics stack, which must never be entered
    // while holding this non-recursive lock.
    NSString *resurfacedName       = nil;
    NSString *resurfacedInstanceId = nil;
    NSString *resurfacedPlatform   = nil;
    NSString *departedName         = nil;
    NSString *departedInstanceId   = nil;

    os_unfair_lock_lock(&_lock);

    // How long the departing instance was actually on screen, captured before it is removed.
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    BOOL wasChurn = NO;
    for (NRMAVisibleView *entry in _visibleViews) {
        if ([entry.instanceId isEqualToString:instanceId]) {
            wasChurn = ([NRMAViewContext millisecondsBetween:entry.appearTime and:now] < kNRMAMinDwellMs);
            break;
        }
    }

    NSUInteger removedIndex = [self removeVisibleViewLocked:instanceId];
    // After the removal, the departing view was on top precisely when it sat at what is now the end
    // of the array. Anything else means it was buried and nothing was uncovered.
    BOOL wasTop = (removedIndex != NSNotFound && removedIndex == _visibleViews.count);

    if (wasTop && !wasChurn && _visibleViews.count > 0 && _currentViewSource == NRMAViewSourceAutomatic) {
        NRMAVisibleView *uncovered = _visibleViews.lastObject;

        // Guard against a same-name resurrection (a view replaced by another instance of itself),
        // which would emit an edge from a screen to itself.
        if (uncovered.name.length > 0 && ![uncovered.name isEqualToString:name]) {
            resurfacedName       = uncovered.name;
            resurfacedInstanceId = [[NSUUID UUID] UUIDString];
            resurfacedPlatform   = uncovered.platform;
            departedName         = [name copy];
            departedInstanceId   = [instanceId copy];

            // A new visible lifetime, so timeVisible restarts from now.
            //
            // The entry's instanceId is deliberately NOT overwritten with resurfacedInstanceId. It is
            // the key -removeVisibleViewLocked: matches on, and only the producer knows it: when this
            // view really does disappear it reports the id it was pushed with. Replacing the key with
            // a UUID no producer holds made the entry unremovable, so it stayed on the stack until the
            // 32-entry cap evicted it -- and any later disappearance could "uncover" it and resurrect
            // a screen the user left minutes ago, stealing the referrer of whatever appeared next.
            uncovered.appearTime = now;

            _previousViewName       = departedName;
            _previousViewInstanceId = departedInstanceId;
            _currentViewName        = uncovered.name;
            _currentViewInstanceId  = resurfacedInstanceId;
            _currentViewAppearTime  = uncovered.appearTime;
            _currentViewSource      = NRMAViewSourceAutomatic;
        }
    }

    os_unfair_lock_unlock(&_lock);

    if (resurfacedName == nil) { return; }

    [self persistCurrentReferrerState];

    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    attrs[kNRAttr_viewName]       = resurfacedName;
    attrs[kNRAttr_viewInstanceId] = resurfacedInstanceId;
    attrs[kNRAttr_previousView]   = departedName;
    attrs[kNRAttr_previousViewId] = departedInstanceId;
    attrs[kNRAttr_appeared]       = @YES;
    // Distinguishes this from an observed appearance so consumers can treat back-navigation
    // separately -- and so it is obvious why there is no loadTime.
    attrs[kNRMAAttributeReappeared] = @YES;
    attrs[kNRAttr_agentName]      = kNRAgentName;
    if (resurfacedPlatform.length > 0) {
        attrs[kNRAttr_uiPlatform] = resurfacedPlatform;
    }
    // Deliberately no loadTime: nothing was constructed or laid out, the screen was merely
    // uncovered. Zeroing it would drag load-time aggregates toward zero.

    [NewRelic recordCustomEvent:kNRMobileViewEventType attributes:attrs];
}

#pragma mark - Manual producer

- (void)setCurrentManualView:(NSString *)name attributes:(NSDictionary<NSString *, id> *)attributes {
    if (name.length == 0) { return; }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSString *newInstanceId = [[NSUUID UUID] UUIDString];

    // Capture the outgoing (current) view and its referrer, then shift, under one lock.
    os_unfair_lock_lock(&_lock);
    NSString *outgoingName   = _currentViewName;
    NSString *outgoingId     = _currentViewInstanceId;
    CFAbsoluteTime outgoingAppear = _currentViewAppearTime;
    BOOL outgoingWasManual   = (_currentViewSource == NRMAViewSourceManual);
    NSString *beforeOutgoing = _previousViewName;      // referrer of the outgoing view
    NSString *beforeOutgoingId = _previousViewInstanceId;

    _previousViewName       = _currentViewName;
    _previousViewInstanceId = _currentViewInstanceId;
    _currentViewName        = [name copy];
    _currentViewInstanceId  = newInstanceId;
    _currentViewAppearTime  = now;
    _currentViewSource      = NRMAViewSourceManual;
    os_unfair_lock_unlock(&_lock);
    [self persistCurrentReferrerState];

    // Close the outgoing view only if the manual API opened it; auto views close via viewDidDisappear.
    if (outgoingName.length > 0 && outgoingWasManual) {
        double timeVisibleMs = [NRMAViewContext millisecondsBetween:outgoingAppear and:now];
        [self recordMobileView:outgoingName
                    instanceId:outgoingId
                  previousView:beforeOutgoing
        previousViewInstanceId:beforeOutgoingId
                      appeared:NO
                   timeVisible:@(timeVisibleMs)
                   customAttrs:nil];
    }

    // Open the new manual view. previousView = the view we just left.
    [self recordMobileView:name
                instanceId:newInstanceId
              previousView:outgoingName
    previousViewInstanceId:outgoingId
                  appeared:YES
               timeVisible:nil
               customAttrs:attributes];
}

- (void)flushCurrentManualViewOnBackground {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

    os_unfair_lock_lock(&_lock);
    if (_currentViewSource != NRMAViewSourceManual || _currentViewName.length == 0) {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    NSString *name        = _currentViewName;
    NSString *instanceId  = _currentViewInstanceId;
    CFAbsoluteTime appear = _currentViewAppearTime;
    NSString *previous    = _previousViewName;
    NSString *previousId  = _previousViewInstanceId;

    // Current view is done; it becomes the previous view.
    _previousViewName       = _currentViewName;
    _previousViewInstanceId = _currentViewInstanceId;
    _currentViewName        = nil;
    _currentViewInstanceId  = nil;
    _currentViewSource      = NRMAViewSourceNone;
    os_unfair_lock_unlock(&_lock);
    [self persistCurrentReferrerState];

    double timeVisibleMs = [NRMAViewContext millisecondsBetween:appear and:now];
    [self recordMobileView:name
                instanceId:instanceId
              previousView:previous
    previousViewInstanceId:previousId
                  appeared:NO
               timeVisible:@(timeVisibleMs)
               customAttrs:nil];
}

// Assembles and records a MobileView event for the manual producer. Reserved keys always win over
// caller-supplied custom attributes to keep the event schema stable.
- (void)recordMobileView:(NSString *)name
              instanceId:(NSString *)instanceId
            previousView:(nullable NSString *)previousView
  previousViewInstanceId:(nullable NSString *)previousViewInstanceId
                appeared:(BOOL)appeared
             timeVisible:(nullable NSNumber *)timeVisibleMs
             customAttrs:(nullable NSDictionary<NSString *, id> *)customAttrs {
    NSMutableDictionary<NSString *, id> *attrs =
        [NSMutableDictionary dictionaryWithDictionary:customAttrs ?: @{}];

    attrs[kNRAttr_viewClass]      = name;   // manual views have no class; name is the identity
    attrs[kNRAttr_viewName]       = name;
    attrs[kNRAttr_viewInstanceId] = instanceId ?: @"";
    attrs[kNRAttr_appeared]       = @(appeared);
    attrs[kNRAttr_uiPlatform]     = kNRUIPlatformManual;
    attrs[kNRAttr_agentName]      = kNRAgentName;
    if (previousView.length > 0) {
        attrs[kNRAttr_previousView] = previousView;
    }
    if (previousViewInstanceId.length > 0) {
        attrs[kNRAttr_previousViewId] = previousViewInstanceId;
    }
    if (timeVisibleMs != nil) {
        attrs[kNRAttr_timeVisible] = timeVisibleMs;
    }

    [NewRelic recordCustomEvent:kNRMobileViewEventType attributes:attrs];
}

#pragma mark - Referrer accessors

- (NSDictionary<NSString *, id> *)referrerAttributes {
    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    os_unfair_lock_lock(&_lock);
    if (_currentViewName.length > 0) {
        attrs[kNRAttr_currentView] = _currentViewName;
    }
    if (_currentViewInstanceId.length > 0) {
        attrs[kNRAttr_currentViewId] = _currentViewInstanceId;
    }
    if (_previousViewName.length > 0) {
        attrs[kNRAttr_previousView] = _previousViewName;
    }
    if (_previousViewInstanceId.length > 0) {
        attrs[kNRAttr_previousViewId] = _previousViewInstanceId;
    }
    os_unfair_lock_unlock(&_lock);
    return attrs;
}

- (NSDictionary<NSString *, id> *)previousViewAttributes {
    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    os_unfair_lock_lock(&_lock);
    if (_previousViewName.length > 0) {
        attrs[kNRAttr_previousView] = _previousViewName;
    }
    if (_previousViewInstanceId.length > 0) {
        attrs[kNRAttr_previousViewId] = _previousViewInstanceId;
    }
    os_unfair_lock_unlock(&_lock);
    return attrs;
}

+ (nullable NSDictionary<NSString *, id> *)mergeReferrerAttributesInto:(nullable NSDictionary<NSString *, id> *)attributes {
    if (![NRMAFlags shouldEnableAutomaticMobileViews] && ![NRMAFlags shouldEnableManualMobileViews]) {
        return attributes;
    }
    NSDictionary<NSString *, id> *referrer = [[NRMAViewContext sharedInstance] referrerAttributes];
    if (referrer.count == 0) {
        return attributes;
    }
    NSMutableDictionary<NSString *, id> *merged = [NSMutableDictionary dictionaryWithDictionary:attributes ?: @{}];
    [merged addEntriesFromDictionary:referrer];
    return merged;
}

#pragma mark - Crash-time referrer recovery

// Documents, not Caches: the crash report itself lives in Caches, but Caches can be purged before
// the report is ever processed. SessionReplayFrames uses Documents for the same reason -- this file
// has the same survival requirement.
+ (NSString *)persistedReferrerStateFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    return [documentsDirectory stringByAppendingPathComponent:kNRMA_LastKnownView_fileName];
}

// Called after every transition, outside the lock: -referrerAttributes takes it again briefly, and
// disk I/O must never happen while it's held. "Last known", written synchronously on the happy
// path, is the whole point -- there is no crash-time hook that could capture this more precisely
// without reintroducing the signal-handler reentrancy hazard this design exists to avoid.
- (void)persistCurrentReferrerState {
    NSDictionary<NSString *, id> *attrs = [self referrerAttributes];
    NSString *path = [NRMAViewContext persistedReferrerStateFilePath];
    if (attrs.count == 0) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        return;
    }
    [attrs writeToFile:path atomically:YES];
}

+ (nullable NSDictionary<NSString *, NSString *> *)persistedReferrerAttributes {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self persistedReferrerStateFilePath]];
    return dict.count > 0 ? dict : nil;
}

+ (void)clearPersistedReferrerAttributes {
    [[NSFileManager defaultManager] removeItemAtPath:[self persistedReferrerStateFilePath] error:nil];
}

#pragma mark - Timing

- (NRMAViewTimingSnapshot *)snapshotForTiming {
    os_unfair_lock_lock(&_lock);
    NSString *name       = _currentViewName;
    NSString *instanceId = _currentViewInstanceId;
    CFAbsoluteTime appear = _currentViewAppearTime;
    NSString *previous   = _previousViewName;
    BOOL hasCurrent      = (_currentViewName.length > 0);

    // Platform is not held alongside _currentView*: automatic producers keep it on their visible-view
    // stack entry, and the manual producer has no entry at all. Resolve it here so the timing event
    // reports the same uiPlatform the MobileView event did.
    NSString *platform = nil;
    if (_currentViewSource == NRMAViewSourceManual) {
        platform = kNRUIPlatformManual;
    } else if (instanceId.length > 0) {
        for (NRMAVisibleView *entry in _visibleViews.reverseObjectEnumerator) {
            if ([entry.instanceId isEqualToString:instanceId]) {
                platform = entry.platform;
                break;
            }
        }
    }
    os_unfair_lock_unlock(&_lock);

    return [[NRMAViewTimingSnapshot alloc] initWithViewName:name
                                            viewInstanceId:instanceId
                                              previousView:previous
                                                uiPlatform:platform
                                                appearTime:appear
                                            hasCurrentView:hasCurrent];
}

+ (double)millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end {
    double ms = (end - start) * 1000.0;
    return MAX(ms, 0.0);
}

@end
