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

static NSString * const kNRUIPlatformManual    = @"Manual";
static NSString * const kNRAgentName           = @"iOS";

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
    }
    return self;
}

#pragma mark - Automatic producers

- (void)transitionToView:(NSString *)name
              instanceId:(NSString *)instanceId
              appearTime:(CFAbsoluteTime)appearTime {
    if (name.length == 0) { return; }
    os_unfair_lock_lock(&_lock);
    _previousViewName       = _currentViewName;
    _previousViewInstanceId = _currentViewInstanceId;
    _currentViewName        = [name copy];
    _currentViewInstanceId  = [instanceId copy];
    _currentViewAppearTime  = appearTime;
    _currentViewSource      = NRMAViewSourceAutomatic;
    os_unfair_lock_unlock(&_lock);
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
