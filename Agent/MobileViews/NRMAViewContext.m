//
//  NRMAViewContext.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAViewContext.h"
#import <os/lock.h>
#import "NewRelic.h"

// MobileView event type + attribute keys (shared schema with NRMAMobileViewTracker).
static NSString * const kNRMobileViewEventType = @"MobileView";
static NSString * const kNRAttr_viewClass      = @"viewClass";
static NSString * const kNRAttr_viewName       = @"viewName";
static NSString * const kNRAttr_viewInstanceId = @"viewInstanceId";
static NSString * const kNRAttr_previousView   = @"previousView";
static NSString * const kNRAttr_previousViewId = @"previousViewInstanceId";
static NSString * const kNRAttr_currentView    = @"currentView";
static NSString * const kNRAttr_timeVisible    = @"timeVisible";
static NSString * const kNRAttr_appeared       = @"appeared";
static NSString * const kNRAttr_uiPlatform     = @"uiPlatform";
static NSString * const kNRAttr_agentName      = @"agentName";
NSString * const kNRMAAttributeInteractionId   = @"interactionId";
NSString * const kNRMAAttributeInteractionName = @"interactionName";
NSString * const kNRMAAttributeReappeared      = @"reappeared";

// Upper bound on the visible-view stack. A producer can miss a disappearance (a view deallocated
// without SwiftUI calling onDisappear, or the agent starting mid-session), and an unbounded stack
// would then grow for the life of the session and resurface long-dead screens. Oldest entries are
// discarded first; they are the least likely to be what the user is looking at.
static const NSUInteger kNRMAMaxVisibleViews = 32;

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

    // Identity of the interaction (activity trace) currently running, published by
    // NRMATraceController. Cleared on completion so view events can never carry a finished
    // interaction's id.
    NSString *_currentInteractionId;
    NSString *_currentInteractionName;

    // The view an interaction is bound to, latched at the moment that view became current rather
    // than read back at interaction completion. See -latchInteractionViewBindingLocked.
    NSString *_boundForInteractionId;
    NSString *_boundViewName;
    NSString *_boundViewInstanceId;
    NSString *_boundPreviousViewName;
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
    _previousViewName       = _currentViewName;
    _previousViewInstanceId = _currentViewInstanceId;
    _currentViewName        = [name copy];
    _currentViewInstanceId  = [instanceId copy];
    _currentViewAppearTime  = appearTime;
    _currentViewSource      = NRMAViewSourceAutomatic;
    [self latchInteractionViewBindingLocked];
    [self pushVisibleViewLocked:name instanceId:instanceId appearTime:appearTime platform:platform];
    os_unfair_lock_unlock(&_lock);
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
    NSString *interactionId        = nil;
    NSString *interactionName      = nil;

    os_unfair_lock_lock(&_lock);

    NSUInteger removedIndex = [self removeVisibleViewLocked:instanceId];
    // After the removal, the departing view was on top precisely when it sat at what is now the end
    // of the array. Anything else means it was buried and nothing was uncovered.
    BOOL wasTop = (removedIndex != NSNotFound && removedIndex == _visibleViews.count);

    if (wasTop && _visibleViews.count > 0 && _currentViewSource == NRMAViewSourceAutomatic) {
        NRMAVisibleView *uncovered = _visibleViews.lastObject;

        // Guard against a same-name resurrection (a view replaced by another instance of itself),
        // which would emit an edge from a screen to itself.
        if (uncovered.name.length > 0 && ![uncovered.name isEqualToString:name]) {
            resurfacedName       = uncovered.name;
            resurfacedInstanceId = [[NSUUID UUID] UUIDString];
            resurfacedPlatform   = uncovered.platform;
            departedName         = [name copy];
            departedInstanceId   = [instanceId copy];

            // This is a new visible lifetime for the uncovered view: fresh instance id so its next
            // timeVisible is measured from now rather than from when it was first pushed.
            uncovered.instanceId = resurfacedInstanceId;
            uncovered.appearTime = CFAbsoluteTimeGetCurrent();

            _previousViewName       = departedName;
            _previousViewInstanceId = departedInstanceId;
            _currentViewName        = uncovered.name;
            _currentViewInstanceId  = resurfacedInstanceId;
            _currentViewAppearTime  = uncovered.appearTime;
            _currentViewSource      = NRMAViewSourceAutomatic;
            [self latchInteractionViewBindingLocked];

            // Read directly rather than via -interactionAttributes, which takes the same lock.
            interactionId   = _currentInteractionId;
            interactionName = _currentInteractionName;
        }
    }

    os_unfair_lock_unlock(&_lock);

    if (resurfacedName == nil) { return; }

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
    if (interactionId.length > 0) {
        attrs[kNRMAAttributeInteractionId] = interactionId;
    }
    if (interactionName.length > 0) {
        attrs[kNRMAAttributeInteractionName] = interactionName;
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
    [self latchInteractionViewBindingLocked];
    os_unfair_lock_unlock(&_lock);

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

    // Identity of the interaction running right now, so this view event can be joined to it.
    // Merged with the agent-owned keys below so caller attributes can never overwrite it.
    // Safe to call here: every caller has already released _lock (os_unfair_lock is not recursive).
    [attrs addEntriesFromDictionary:[self interactionAttributes]];

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

#pragma mark - Interaction correlation

// LOCK ORDER: NRMATraceController holds kNRMAStartAndEndTracingLock while calling in here, so the
// edge is trace lock -> view lock. Nothing in this class may call back into NRMATraceController;
// the dependency has to stay one-way or the two locks can deadlock.
- (void)setCurrentInteractionId:(NSString *)interactionId name:(NSString *)name {
    os_unfair_lock_lock(&_lock);
    // A different interaction (or none) invalidates the latch. Note that -startTracingWithName:
    // re-publishes the *same* id once the real name is known, so compare ids rather than clearing
    // unconditionally — otherwise that second publish would drop a binding already latched.
    if (![_currentInteractionId isEqualToString:interactionId]) {
        _boundForInteractionId = nil;
        _boundViewName         = nil;
        _boundViewInstanceId   = nil;
        _boundPreviousViewName = nil;
    }
    _currentInteractionId   = [interactionId copy];
    _currentInteractionName = [name copy];
    os_unfair_lock_unlock(&_lock);
}

- (void)clearCurrentInteractionIdIfEqualTo:(NSString *)interactionId {
    os_unfair_lock_lock(&_lock);
    // Compare-and-clear under the lock. Reading the id out, comparing, then clearing would let a
    // sibling interaction publish in between and have its identity wiped by this call.
    if (interactionId.length == 0 || [_currentInteractionId isEqualToString:interactionId]) {
        _currentInteractionId   = nil;
        _currentInteractionName = nil;
        _boundForInteractionId  = nil;
        _boundViewName          = nil;
        _boundViewInstanceId    = nil;
        _boundPreviousViewName  = nil;
    }
    os_unfair_lock_unlock(&_lock);
}

// Binds the running interaction to whichever view is current at this instant. Callers MUST hold
// _lock (os_unfair_lock is not recursive, so this must never be called from an unlocked path).
//
// Why latch rather than read the current view at interaction completion, which is what §3.2 of the
// correlation design doc describes: reading at completion was only correct because the quiescence
// timeout was 0.5s — long enough for viewDidAppear: to have landed, short enough that the user could
// not have navigated away yet. Once an interaction can span a screen's dwell time (and a custom
// interaction is immune to supersession entirely, -isInteractionObject: always returns YES for it),
// a completion-time read would attribute a screen load to whatever screen was current when the timer
// finally fired. §9 of that doc already listed this as a best-effort risk on the unhealthy path; the
// latch removes it for every path.
//
// Only the first transition after an interaction starts is latched. An auto-interaction begins in
// viewDidLoad/viewWillAppear: while the *outgoing* screen is still current, so the first view to
// become current after that is the screen the interaction actually describes.
- (void)latchInteractionViewBindingLocked {
    if (_currentInteractionId.length == 0) { return; }
    if ([_boundForInteractionId isEqualToString:_currentInteractionId]) { return; }

    _boundForInteractionId = [_currentInteractionId copy];
    _boundViewName         = _currentViewName;
    _boundViewInstanceId   = _currentViewInstanceId;
    _boundPreviousViewName = _previousViewName;
}

- (NSDictionary<NSString *, id> *)interactionAttributes {
    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    os_unfair_lock_lock(&_lock);
    if (_currentInteractionId.length > 0) {
        attrs[kNRMAAttributeInteractionId] = _currentInteractionId;
    }
    if (_currentInteractionName.length > 0) {
        attrs[kNRMAAttributeInteractionName] = _currentInteractionName;
    }
    os_unfair_lock_unlock(&_lock);
    return attrs;
}

- (NSDictionary<NSString *, id> *)viewCorrelationAttributes {
    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    os_unfair_lock_lock(&_lock);

    // Prefer the view latched when this interaction's screen became current. Falls back to the
    // current view when nothing was ever latched — an interaction that started and finished without
    // any view transition (a custom interaction around a background task, say), where the current
    // view is still the best available answer and matches the pre-latch behaviour.
    BOOL haveLatch = (_boundViewName.length > 0
                      && [_boundForInteractionId isEqualToString:_currentInteractionId]);

    NSString *viewName       = haveLatch ? _boundViewName         : _currentViewName;
    NSString *viewInstanceId = haveLatch ? _boundViewInstanceId   : _currentViewInstanceId;
    NSString *previousView   = haveLatch ? _boundPreviousViewName : _previousViewName;

    if (viewName.length > 0) {
        attrs[kNRAttr_viewName] = viewName;
    }
    if (viewInstanceId.length > 0) {
        attrs[kNRAttr_viewInstanceId] = viewInstanceId;
    }
    if (previousView.length > 0) {
        attrs[kNRAttr_previousView] = previousView;
    }
    os_unfair_lock_unlock(&_lock);
    return attrs;
}

#pragma mark - Referrer accessors

- (NSDictionary<NSString *, id> *)referrerAttributes {
    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    os_unfair_lock_lock(&_lock);
    if (_currentViewName.length > 0) {
        attrs[kNRAttr_currentView] = _currentViewName;
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

#pragma mark - Timing

+ (double)millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end {
    double ms = (end - start) * 1000.0;
    return MAX(ms, 0.0);
}

@end
