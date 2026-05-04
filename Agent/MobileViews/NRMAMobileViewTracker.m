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

// Returns YES if the given class or class-name prefix should be excluded from tracking.
FOUNDATION_EXPORT BOOL NRMA_ShouldSkipClass(Class cls);
                                                                                  
// Canonical list of SwiftUI host/container class-name prefixes we skip.
FOUNDATION_EXPORT NSArray<NSString *> * const NRMAExcludedViewClassPrefixes(void);
                                                                                             
NSArray<NSString *> * const NRMAExcludedViewClassPrefixes(void) {
    static NSArray<NSString *> *prefixes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prefixes = @[
            @"UIHostingController",
            @"NavigationStackHostingController",
            @"StyleContextSplitViewNavigationController",
            @"PresentationHostingController",
        ];
    });
    return prefixes;
}

#pragma mark - Swift name demangling

/**
 * Strips the outermost module prefix from a (possibly generic) type name.
 *
 * Scans for the first '.' at angle-bracket depth 0, which is the module separator.
 * This avoids the "trailing >" bug caused by finding a '.' inside generic params.
 *
 *   "NRTestApp.ProductViewController"            → "ProductViewController"
 *   "SwiftUI.UIHostingController<NRTestApp.Foo>" → "UIHostingController<NRTestApp.Foo>"
 *   "UIViewController"                           → "UIViewController"  (no dot → unchanged)
 */
static NSString *NRMA_StripOuterModule(NSString *name) {
    NSUInteger depth = 0;
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        if      (c == '<') depth++;
        else if (c == '>') { if (depth > 0) depth--; }
        else if (c == '.' && depth == 0) {
            return [name substringFromIndex:i + 1];
        }
    }
    return name;
}

/**
 * Returns the demangled type name for `cls`.
 *
 * - fullName YES → "ModuleName.ClassName"  (viewClass attribute)
 * - fullName NO  → "ClassName"             (viewName attribute)
 *
 * Handles three cases:
 *   1. Mangled Swift names (_Tt…): demangled via swift_demangle, then module-stripped if needed.
 *   2. Already-demangled module-qualified names (e.g. "NRTestApp.Foo" returned directly by
 *      newer Swift runtimes): module-stripped without demangling step.
 *   3. Plain ObjC names ("UIViewController"): returned as-is for fullName, or unchanged since
 *      there is no module prefix to strip.
 */
static NSString *NRMA_DemangledName(Class cls, BOOL fullName) {
    NSString *rawName = NSStringFromClass(cls);
    NSString *qualified = rawName;

    if ([rawName hasPrefix:kSwiftManglingMarker]) {
        typedef char *(*SwiftDemangle)(const char *, size_t, char *, size_t *, uint32_t);
        static SwiftDemangle demangle = NULL;
        static dispatch_once_t token;
        dispatch_once(&token, ^{
            demangle = (SwiftDemangle)dlsym(RTLD_DEFAULT, "swift_demangle");
        });
        if (demangle) {
            const char *cstr = [rawName UTF8String];
            size_t outLen = 0;
            char *buf = demangle(cstr, strlen(cstr), NULL, &outLen, 0);
            if (buf) {
                qualified = [NSString stringWithUTF8String:buf];
                free(buf);
            }
        }
    }

    if (fullName) {
        return qualified;
    }

    // Strip outermost module prefix for the simple viewName.
    // Works on both swift_demangle output and names already returned demangled
    // by the runtime (e.g. "NRTestApp.TextMaskingViewController").
    return NRMA_StripOuterModule(qualified);
}

// Storage for original IMPs — set once during swizzle setup
static void (*orig_viewDidLoad)(id, SEL);
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void (*orig_viewDidDisappear)(id, SEL, BOOL);

#pragma mark - Helpers

BOOL NRMA_ShouldSkipViewName(NSString *viewName) {
    for (NSString *prefix in NRMAExcludedViewClassPrefixes()) {
        if ([viewName hasPrefix:prefix]) return YES;
    }
    return NO;
}

BOOL NRMA_ShouldSkipClass(Class cls) {
    return NRMA_ShouldSkipViewName(NSStringFromClass(cls));
}

// File-private — used only for a type-safe cast when calling the informal hook.
// Developers never need to adopt this; it exists solely to avoid a compiler warning.
@protocol _NRMVNameHook <NSObject>
- (NSString *)nrMobileViewName;
@end

#if !TARGET_OS_WATCH

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

    if ([viewName hasPrefix:@"UIHostingController"]) return;
    if ([viewName hasPrefix:@"NavigationStackHostingController"]) return;
    if ([viewName hasPrefix:@"StyleContextSplitViewNavigationController"]) return;
    if ([viewName hasPrefix:@"PresentationHostingController"]) return;
    [NewRelic recordCustomEvent:kNRMobileViewEventType
                     attributes:@{
        kNRAttr_viewClass:      viewClass,
        kNRAttr_viewName:       viewName,
        kNRAttr_viewInstanceId: instanceId,
        kNRAttr_restarted:      @(isRestarted),
        kNRAttr_loadTime:       @(loadTimeSec),
        kNRAttr_timeVisible:    @(timeVisibleSec),
        @"uiPlatform":       @"UIKit",
    }];

    //NRLOG_AGENT_VERBOSE(@"[MobileViews] %@ — loadTime=%.1fms timeVisible=%.1fms restarted=%@",
    //                    viewName, loadTimeSec, timeVisibleSec, isRestarted ? @"YES" : @"NO");

    // Mark that this VC has appeared at least once (restarted = YES on next display)
    objc_setAssociatedObject(self, &kNRHasAppearedBeforeKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Clear per-instance timing so stale data isn't carried forward
    objc_setAssociatedObject(self, &kNRLoadTimestampKey,   nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kNRAppearTimestampKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kNRViewInstanceIdKey,  nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
#endif

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
#if !TARGET_OS_WATCH

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
#endif
        NRLOG_AGENT_INFO(@"[MobileViews] UIViewController lifecycle tracking started.");
    });
}

@end
