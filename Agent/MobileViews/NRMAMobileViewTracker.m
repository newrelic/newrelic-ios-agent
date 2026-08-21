//
//  NRMAMobileViewTracker.m
//  NewRelicAgent
//
//  MobileViews: automatic UIViewController lifecycle tracking. Emits "MobileView" custom events
//  with timing and identity attributes, and updates NRMAViewContext so breadcrumbs and MobileView
//  events carry a consistent currentView / previousView referrer.
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
#import "NRMAViewContext.h"
#import "NRMATraceController.h"
#import "NRMAFlags.h"

// Associated-object keys (pointer address acts as unique key)
static const char kNRLoadTimestampKey;
static const char kNRAppearTimestampKey;
static const char kNRViewInstanceIdKey;
static const char kNRHasAppearedBeforeKey;

static NSString * const kNRMobileViewEventType = @"MobileView";

// The class half of a load segment's `Method/MobileView/<viewName>` metric name: one stable prefix
// for every tracked screen, so the rows group together wherever metric names are matched.
static NSString * const kNRMobileViewSegmentClassLabel = @"MobileView";

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
            @"UIKitTabBarController",
            @"TabHostingController",
            @"UIHostingController",
            @"UINavigationController",
            @"NavigationStackHostingController",
            @"StyleContextSplitViewNavigationController",
            @"PresentationHostingController",
            @"UICompatibilityInputViewController",
            @"UIPredictionViewController",
            @"UISystemInputAssistantViewController",
            @"UICompatibilityInputViewController",
            @"UIKitNavigationController",
            @"_UICursorAccessoryViewController",
            @"NotifyingMulticolumnSplitViewController",
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

// File-private — used only for a type-safe cast when calling the informal hooks.
// Developers never need to adopt these; they exist solely to avoid compiler warnings.
@protocol _NRMVNameHook <NSObject>
- (nullable NSString *)nrMobileViewName;
@end

@protocol _NRMVAttrHook <NSObject>
- (nullable NSDictionary<NSString *, id> *)nrMobileViewAttributes;
@end

#if !TARGET_OS_WATCH

/**
 * Resolves the display name for a view controller, honoring the optional
 * nrMobileViewName hook.
 *
 * Returns nil to signal "ignore this view" — happens only when the VC implements
 * nrMobileViewName and explicitly returns nil. Empty string falls back to the
 * demangled class name (legacy behavior).
 */
NS_INLINE NSString * _Nullable NRMA_ViewNameForController(UIViewController *vc) {
    SEL sel = @selector(nrMobileViewName);
    if ([vc respondsToSelector:sel]) {
        NSString *custom = [(id<_NRMVNameHook>)vc nrMobileViewName];
        if (custom == nil) {
            // Explicit nil = caller wants this view ignored.
            return nil;
        }
        if (custom.length > 0) return custom;
        // Empty string: fall through to class name.
    }
    // Demangled simple name, e.g. "ProductDetailViewController"
    return NRMA_DemangledName([vc class], NO);
}

/**
 * Returns custom attributes from the optional nrMobileViewAttributes hook, or nil.
 * Attributes are merged into emitted MobileView events; reserved keys win.
 */
NS_INLINE NSDictionary<NSString *, id> * _Nullable NRMA_AttributesForController(UIViewController *vc) {
    SEL sel = @selector(nrMobileViewAttributes);
    if ([vc respondsToSelector:sel]) {
        return [(id<_NRMVAttrHook>)vc nrMobileViewAttributes];
    }
    return nil;
}

#pragma mark - Swizzled method implementations

static void NRMA_ViewDidLoad(UIViewController *self, SEL _cmd) {
    if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);

    if (NRMA_ShouldSkipClass([self class])) return;

    NSString *viewName  = NRMA_ViewNameForController(self);
    // nil viewName = caller's nrMobileViewName returned nil → ignore this view.
    if (viewName == nil) return;
    if (NRMA_ShouldSkipViewName(viewName)) return;

    objc_setAssociatedObject(self, &kNRLoadTimestampKey,
                             @(CFAbsoluteTimeGetCurrent()),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void NRMA_ViewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewDidAppear) orig_viewDidAppear(self, _cmd, animated);

    if (NRMA_ShouldSkipClass([self class])) return;

    NSString *viewName  = NRMA_ViewNameForController(self);
    if (viewName == nil) return;
    if (NRMA_ShouldSkipViewName(viewName)) return;

    CFAbsoluteTime appearTime = CFAbsoluteTimeGetCurrent();
    objc_setAssociatedObject(self, &kNRAppearTimestampKey,
                             @(appearTime),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *uuid = [[NSUUID UUID] UUIDString];
    // Fresh UUID for this single visible-lifetime instance
    objc_setAssociatedObject(self, &kNRViewInstanceIdKey,
                             uuid,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Make this view current in the shared context so it becomes the referrer for the next view
    // and for breadcrumbs recorded while it is visible.
    [[NRMAViewContext sharedInstance] transitionToView:viewName
                                            instanceId:uuid
                                            appearTime:appearTime
                                              platform:@"UIKit"];

    // Put the screen's load span in the covering interaction's breakdown. Read back rather than
    // passed down because viewDidLoad may never have run for this appearance.
    NSNumber *loadTimestamp = objc_getAssociatedObject(self, &kNRLoadTimestampKey);
    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:viewName
                                               loadTime:loadTimestamp ? loadTimestamp.doubleValue : 0
                                             appearTime:appearTime];

    NSString *viewClass = NRMA_DemangledName([self class], YES);

    NSDictionary<NSString *, id> *custom = NRMA_AttributesForController(self);
    NSMutableDictionary<NSString *, id> *attrs =
        [NSMutableDictionary dictionaryWithDictionary:custom ?: @{}];
    // Referrer for this appearance (previousView / previousViewInstanceId).
    [attrs addEntriesFromDictionary:[[NRMAViewContext sharedInstance] previousViewAttributes]];
    // Identity of the interaction (activity trace) covering this appearance, so the screen can be
    // joined to its code-level trace. Absent when no interaction is running.
    [attrs addEntriesFromDictionary:[[NRMAViewContext sharedInstance] interactionAttributes]];
    // Reserved keys win over caller-supplied ones to keep the event schema stable.
    [attrs addEntriesFromDictionary:@{
        kNRAttr_viewClass:      viewClass,
        kNRAttr_viewName:       viewName,
        kNRAttr_viewInstanceId: uuid,
        @"appeared":            @YES,
        @"uiPlatform":          @"UIKit",
        @"agentName":           @"iOS",
    }];
    // loadTime belongs here and not only on the disappear event, which is where this producer used
    // to report it alone. The appear event is the one that also carries interactionId — by
    // viewDidDisappear: the covering interaction has normally completed and NRMAViewContext has
    // cleared it — so this is the only event from which a load cost can be joined to the trace that
    // measured it. It also brings the UIKit schema in line with the SwiftUI producer, which has
    // always put loadTime on appear.
    //
    // Omitted rather than zeroed when viewDidLoad was never observed for this appearance (agent
    // started mid-session), so aggregates are not dragged toward 0 by a placeholder.
    if (loadTimestamp) {
        attrs[kNRAttr_loadTime] = @([NRMAViewContext millisecondsBetween:loadTimestamp.doubleValue
                                                                    and:appearTime]);
    }

    // Both halves of a view's lifetime are recorded, and they carry different things: this one
    // loadTime and interactionId, the disappear event timeVisible.
    [NewRelic recordCustomEvent:kNRMobileViewEventType attributes:attrs];
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
        // viewDidAppear was never observed for this instance (agent started mid-session,
        // or the view was ignored on appear).
        return;
    }

    // viewName: simple demangled name (or custom override), e.g. "ProductDetailViewController"
    NSString *viewName  = NRMA_ViewNameForController(self);
    if (viewName == nil) return;

    double timeVisibleMs = [NRMAViewContext millisecondsBetween:appearTimestamp.doubleValue and:disappearTime];
    double loadTimeMs    = 0.0;
    if (loadTimestamp) {
        loadTimeMs = [NRMAViewContext millisecondsBetween:loadTimestamp.doubleValue and:appearTimestamp.doubleValue];
    }

    BOOL isRestarted = (hasAppearedBefore != nil && hasAppearedBefore.boolValue);
    // viewClass: fully-qualified demangled name, e.g. "MyApp.ProductDetailViewController"
    NSString *viewClass = NRMA_DemangledName([self class], YES);

    NSDictionary<NSString *, id> *custom = NRMA_AttributesForController(self);
    NSMutableDictionary<NSString *, id> *attrs =
        [NSMutableDictionary dictionaryWithDictionary:custom ?: @{}];
    // Usually absent here: the load interaction has normally completed by the time the view goes
    // away. Present when an interaction is still running (or a new one has started).
    [attrs addEntriesFromDictionary:[[NRMAViewContext sharedInstance] interactionAttributes]];
    [attrs addEntriesFromDictionary:@{
        kNRAttr_viewClass:      viewClass,
        kNRAttr_viewName:       viewName,
        kNRAttr_viewInstanceId: instanceId,
        kNRAttr_restarted:      @(isRestarted),
        kNRAttr_loadTime:       @(loadTimeMs),
        kNRAttr_timeVisible:    @(timeVisibleMs),
        @"appeared":            @NO,
        @"uiPlatform":          @"UIKit",
        @"agentName":           @"iOS",
    }];

    [NewRelic recordCustomEvent:kNRMobileViewEventType attributes:attrs];

    // Drop this instance from the visible-view stack. For UIKit this is bookkeeping rather than a
    // fix: viewDidAppear: fires on pop, so the uncovered screen reports a real appearance moments
    // from now, which supersedes anything synthesized here. Keeping the stack accurate matters
    // because a UIKit controller can be what a *SwiftUI* view was covering.
    [[NRMAViewContext sharedInstance] viewDidDisappearNamed:viewName instanceId:instanceId];

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

// CFAbsoluteTime (seconds since 2001) → the milliseconds-since-epoch domain trace timestamps use.
NS_INLINE double NRMA_EpochMillisFromAbsoluteTime(CFAbsoluteTime absoluteTime) {
    return (absoluteTime + kCFAbsoluteTimeIntervalSince1970) * 1000;
}

@implementation NRMAMobileViewTracker

+ (instancetype)sharedInstance {
    static NRMAMobileViewTracker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NRMAMobileViewTracker alloc] init];
    });
    return instance;
}

+ (void)recordLoadSegmentForViewNamed:(NSString *)viewName
                             loadTime:(CFAbsoluteTime)loadTime
                           appearTime:(CFAbsoluteTime)appearTime {
    // The feature flag has to hold here too, not just at swizzle-install time: the SwiftUI
    // producer is compiled into the host app's view tree and reaches this method directly.
    if (![NRMAFlags shouldEnableAutomaticMobileViews]) {
        return;
    }
    if (viewName.length == 0) {
        return;
    }
    // loadTime of 0 is "never observed", so the span is unknown rather than instantaneous —
    // recording it would date the segment's start to 2001. A backwards span is equally unusable.
    if (loadTime <= 0 || appearTime <= loadTime) {
        return;
    }

    [NRMATraceController recordCompletedSegmentWithObjectNamed:kNRMobileViewSegmentClassLabel
                                                  methodNamed:viewName
                                         entryTimestampMillis:NRMA_EpochMillisFromAbsoluteTime(loadTime)
                                          exitTimestampMillis:NRMA_EpochMillisFromAbsoluteTime(appearTime)
                                                traceCategory:NRTraceTypeMobileView];
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
        NRLOG_AGENT_INFO(@"[MobileViews] UIViewController lifecycle tracking started.");
#endif

    });
}

@end
