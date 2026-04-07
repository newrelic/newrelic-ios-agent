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
#import <dlfcn.h>
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

// Swift mangling marker — any class name starting with _Tt is mangled
static NSString * const kSwiftManglingMarker = @"_Tt";

#pragma mark - Swift name demangling

/**
 * Returns the demangled Swift type name for `cls`, or the raw ObjC class name if
 * no demangling is needed / available.
 *
 * - `fullName`  YES → "ModuleName.ClassName"  (for viewClass attribute)
 * - `fullName`  NO  → "ClassName"             (for viewName attribute)
 *
 * swift_demangle is a public symbol in the Swift runtime dylib; we look it up
 * lazily via dlsym so we don't need to link against a specific Swift library.
 */
static NSString *NRMA_DemangledName(Class cls, BOOL fullName) {
    NSString *rawName = NSStringFromClass(cls);

    if (![rawName hasPrefix:kSwiftManglingMarker]) {
        // Plain ObjC class — already human-readable
        return rawName;
    }

    // Resolve swift_demangle once
    typedef char *(*SwiftDemangle)(const char *, size_t, char *, size_t *, uint32_t);
    static SwiftDemangle demangle = NULL;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        demangle = (SwiftDemangle)dlsym(RTLD_DEFAULT, "swift_demangle");
    });

    if (!demangle) {
        return rawName;
    }

    const char *mangledCStr = [rawName UTF8String];
    size_t outputLen = 0;
    char *demangled = demangle(mangledCStr, strlen(mangledCStr), NULL, &outputLen, 0);

    if (!demangled) {
        return rawName;
    }

    // demangled is e.g. "MyApp.MyViewController" — caller owns the buffer
    NSString *full = [NSString stringWithUTF8String:demangled];
    free(demangled);

    if (fullName) {
        return full;
    }

    // Strip the module prefix (everything up to and including the last '.')
    NSRange dot = [full rangeOfString:@"." options:NSBackwardsSearch];
    if (dot.location != NSNotFound) {
        return [full substringFromIndex:dot.location + 1];
    }
    return full;
}

// Storage for original IMPs — set once during swizzle setup
static void (*orig_viewDidLoad)(id, SEL);
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void (*orig_viewDidDisappear)(id, SEL, BOOL);

#pragma mark - Helpers

NS_INLINE BOOL NRMA_ShouldSkipClass(Class cls) {
    // Skip SwiftUI framework hosting internals only — NRMobileView modifier handles those.
    // Do NOT skip _TtC-prefixed names: that prefix means "Swift class with ObjC parent",
    // which covers all Swift UIViewController subclasses and is exactly what we want to track.
    NSString *name = NSStringFromClass(cls);
    return [name hasPrefix:kSwiftUIPrefix];
}

// File-private — used only for a type-safe cast when calling the informal hook.
// Developers never need to adopt this; it exists solely to avoid a compiler warning.
@protocol _NRMVNameHook <NSObject>
- (NSString *)nrMobileViewName;
@end

NS_INLINE NSString *NRMA_ViewNameForController(UIViewController *vc) {
    // Informal protocol: if the VC implements nrMobileViewName (ObjC or @objc Swift),
    // use it; otherwise fall back to the demangled class name.
    SEL sel = @selector(nrMobileViewName);
    if ([vc respondsToSelector:sel]) {
        NSString *custom = [(id<_NRMVNameHook>)vc nrMobileViewName];
        if (custom.length > 0) return custom;
    }
    // Demangled simple name, e.g. "ProductDetailViewController"
    return NRMA_DemangledName([vc class], NO);
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
    // viewClass: fully-qualified demangled name, e.g. "MyApp.ProductDetailViewController"
    NSString *viewClass = NRMA_DemangledName([self class], YES);
    // viewName: simple demangled name (or custom override), e.g. "ProductDetailViewController"
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
