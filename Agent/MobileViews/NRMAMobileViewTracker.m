//
//  NRMAMobileViewTracker.m
//  NewRelicAgent
//
//  POC: MobileViews feature — automatic UIViewController lifecycle tracking.
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAMobileViewTracker.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "NewRelic.h"
#import "NRLogger.h"
#import "NRMAMethodSwizzling.h"

// Associated-object keys (pointer address acts as unique key)
static const char kNRLoadTimestampKey;
static const char kNRAppearTimestampKey;
static const char kNRViewInstanceIdKey;
static const char kNRHasAppearedBeforeKey;

static NSString * const kNRMobileViewEventType = @"MobileView";

// Attribute keys matching the PM spec
static NSString * const kNRAttr_viewClass      = @"viewClass";
static NSString * const kNRAttr_viewName       = @"viewName";
static NSString * const kNRAttr_viewInstanceId = @"viewInstanceId";
static NSString * const kNRAttr_restarted      = @"restarted";
static NSString * const kNRAttr_loadTime       = @"loadTime";
static NSString * const kNRAttr_timeVisible    = @"timeVisible";

// Swift class prefix to skip (NRViewModifier handles SwiftUI views)
static NSString * const kSwiftMangledPrefix = @"_TtC";
static NSString * const kSwiftUIPrefix      = @"SwiftUI.";

// Storage for original IMPs — set once during swizzle setup
static void (*orig_viewDidLoad)(id, SEL);
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void (*orig_viewDidDisappear)(id, SEL, BOOL);

#pragma mark - Helpers

NS_INLINE BOOL NRMA_ShouldSkipClass(Class cls) {
    NSString *name = NSStringFromClass(cls);
    return [name hasPrefix:kSwiftMangledPrefix] || [name hasPrefix:kSwiftUIPrefix];
}

NS_INLINE NSString *NRMA_ViewNameForController(UIViewController *vc) {
    if ([vc conformsToProtocol:@protocol(NRMobileViewNameProvider)] &&
        [vc respondsToSelector:@selector(nrMobileViewName)]) {
        NSString *custom = [(id<NRMobileViewNameProvider>)vc nrMobileViewName];
        if (custom.length > 0) return custom;
    }
    return NSStringFromClass([vc class]);
}

#pragma mark - Swizzled method implementations

static void NRMA_ViewDidLoad(UIViewController *self, SEL _cmd) {
    if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);

    if (NRMA_ShouldSkipClass([self class])) return;

    objc_setAssociatedObject(self, &kNRLoadTimestampKey,
                             @(CFAbsoluteTimeGetCurrent()),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void NRMA_ViewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewDidAppear) orig_viewDidAppear(self, _cmd, animated);

    if (NRMA_ShouldSkipClass([self class])) return;

    objc_setAssociatedObject(self, &kNRAppearTimestampKey,
                             @(CFAbsoluteTimeGetCurrent()),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Fresh UUID for this single visible-lifetime instance
    objc_setAssociatedObject(self, &kNRViewInstanceIdKey,
                             [[NSUUID UUID] UUIDString],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void NRMA_ViewDidDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewDidDisappear) orig_viewDidDisappear(self, _cmd, animated);

    if (NRMA_ShouldSkipClass([self class])) return;

    CFAbsoluteTime disappearTime = CFAbsoluteTimeGetCurrent();

    NSNumber *appearTimestamp    = objc_getAssociatedObject(self, &kNRAppearTimestampKey);
    NSNumber *loadTimestamp      = objc_getAssociatedObject(self, &kNRLoadTimestampKey);
    NSString *instanceId         = objc_getAssociatedObject(self, &kNRViewInstanceIdKey);
    NSNumber *hasAppearedBefore  = objc_getAssociatedObject(self, &kNRHasAppearedBeforeKey);

    if (!appearTimestamp || !instanceId) {
        // viewDidAppear was never observed for this instance (agent started mid-session)
        return;
    }

    double timeVisibleSec = (disappearTime - appearTimestamp.doubleValue); //* 1000.0;
    double loadTimeSec    = 0.0;
    if (loadTimestamp) {
        double raw = (appearTimestamp.doubleValue - loadTimestamp.doubleValue); //* 1000.0;
        loadTimeSec = MAX(raw, 0.0);
    }

    BOOL isRestarted = (hasAppearedBefore != nil && hasAppearedBefore.boolValue);
    NSString *viewClass = NSStringFromClass([self class]);
    NSString *viewName  = NRMA_ViewNameForController(self);

    [NewRelic recordCustomEvent:kNRMobileViewEventType
                     attributes:@{
        kNRAttr_viewClass:      viewClass,
        kNRAttr_viewName:       viewName,
        kNRAttr_viewInstanceId: instanceId,
        kNRAttr_restarted:      @(isRestarted),
        kNRAttr_loadTime:       @(loadTimeSec),
        kNRAttr_timeVisible:    @(timeVisibleSec),
    }];

    NRLOG_AGENT_VERBOSE(@"[MobileViews] %@ — loadTime=%.1fms timeVisible=%.1fms restarted=%@",
                        viewName, loadTimeSec, timeVisibleSec, isRestarted ? @"YES" : @"NO");

    // Mark that this VC has appeared at least once (restarted = YES on next display)
    objc_setAssociatedObject(self, &kNRHasAppearedBeforeKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Clear per-instance timing so stale data isn't carried forward
    objc_setAssociatedObject(self, &kNRLoadTimestampKey,   nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kNRAppearTimestampKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kNRViewInstanceIdKey,  nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - NRMAMobileViewTracker

@implementation NRMAMobileViewTracker

+ (instancetype)sharedInstance {
    static NRMAMobileViewTracker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NRMAMobileViewTracker alloc] init];
    });
    return instance;
}

- (void)start {
    static dispatch_once_t swizzleOnce;
    dispatch_once(&swizzleOnce, ^{
        Class vcClass = [UIViewController class];

        orig_viewDidLoad = (void(*)(id,SEL))
            NRMAReplaceInstanceMethod(vcClass,
                                     @selector(viewDidLoad),
                                     (IMP)NRMA_ViewDidLoad);

        orig_viewDidAppear = (void(*)(id,SEL,BOOL))
            NRMAReplaceInstanceMethod(vcClass,
                                     @selector(viewDidAppear:),
                                     (IMP)NRMA_ViewDidAppear);

        orig_viewDidDisappear = (void(*)(id,SEL,BOOL))
            NRMAReplaceInstanceMethod(vcClass,
                                     @selector(viewDidDisappear:),
                                     (IMP)NRMA_ViewDidDisappear);

        NRLOG_AGENT_INFO(@"[MobileViews] UIViewController lifecycle tracking started.");
    });
}

@end
