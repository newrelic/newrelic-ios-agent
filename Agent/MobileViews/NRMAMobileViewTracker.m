//
//  NRMAMobileViewTracker.m
//  NewRelicAgent
//
//  MobileViews: automatic UIViewController lifecycle tracking. Reports view lifecycle facts to
//  NRMAMobileViewRecorder, which owns the MobileView schema, and updates NRMAViewContext so
//  breadcrumbs and MobileView events carry a consistent currentView / previousView referrer.
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAMobileViewTracker.h"
#import <UIKit/UIKit.h>
#import <os/lock.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "NRLogger.h"
#import "NRMAMethodSwizzling.h"
#import "NRMAViewContext.h"
#import "NRMAViewTiming.h"
#import "NRMAFlags.h"
#import <NewRelic/NewRelic-Swift.h>

// Associated-object keys (pointer address acts as unique key)
static const char kNRLoadTimestampKey;
static const char kNRAppearTimestampKey;
static const char kNRViewInstanceIdKey;
// The referrer as of this appearance (a dictionary of previousView / previousViewInstanceId).
// Captured at viewDidAppear: and held until the single event is emitted at viewDidDisappear:,
// because by then the shared context's "previous view" is this screen itself and whatever
// replaced it is current -- reading the referrer at emit time would name the wrong screen.
static const char kNRReferrerKey;
// Caches the resolved SwiftUI screen for a hosting controller. Cached rather than re-resolved so
// the emitted event cannot report a different viewName than the appearance it describes -- and so
// the mirror walk in the resolver runs once per screen instead of once per appearance.
static const char kNRSwiftUIScreenKey;

// Attribute names, the event type, and the loadTime-vs-loadTimeUnavailable rule all live in
// MobileViewEmitter.swift now. This file reports facts; it does not build events.

// The reason string handed to the recorder when a construction interval cannot be trusted.
static NSString * const kNRLoadUnavailableConstructedBeforeAppear = @"constructedBeforeAppear";
static NSString * const kNRLoadUnavailableNoConstructionObserved  = @"noConstructionObserved";

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
            @"_UISceneHostingViewController",
            @"UISystemKeyboardDockController",
            @"UIInputWindowController",
            @"UITrackingElementWindowController",
            @"UIKitTabBarController",
            // Plain UITabBarController was missing while UIKitTabBarController (the SwiftUI-backed
            // container on newer OSes) and UINavigationController were both here -- an omission, not a
            // decision. It is a container, not a screen: a tab switch is reported by the child view
            // controllers' own viewDidAppear:/viewDidDisappear:, so tracking the container adds no
            // signal. It did add harm. Because UIKit fires the outgoing tab's viewDidDisappear:
            // *before* the incoming tab's viewDidAppear:, the container sat underneath on the visible
            // stack and was "uncovered" on every switch -- synthesizing a re-appearance of the tab bar
            // itself, and making it the previousView of the incoming tab instead of the tab left
            // behind. A user's own UITabBarController subclass has its own class name and is
            // unaffected.
            @"UITabBarController",
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
            // An alert or action sheet interrupts a screen; it is not one. Reported, a logout
            // confirmation became a visit of its own and the referrer of the screen after it.
            @"UIAlertController",
            @"NotifyingMulticolumnSplitViewController",
            @"_UIContextMenu"
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

#if !TARGET_OS_WATCH

/*
 * Controllers believed to be on screen: appeared and not yet disappeared.
 *
 * The per-visit facts live as associated objects on the controllers themselves, which is enough for
 * viewDidAppear:/viewDidDisappear: -- each call already has the controller in hand. Backgrounding
 * does not: the app is going away with views still on screen, and there is no lifecycle callback
 * per controller to hang the close-out on (neither viewDidDisappear: nor viewWillDisappear: fires
 * when an app is backgrounded). So the set has to be enumerable, which is what this is for.
 *
 * Held weakly and in appear order. Weakly because a controller must not be kept alive by the agent
 * observing it; in order because the foreground path re-pushes these onto the shared view context's
 * visible stack, and the stack is meaningful only bottom-up -- pushing them in a different order
 * would make the wrong screen current.
 */
@interface NRMAOnScreenController : NSObject
@property (nonatomic, weak) UIViewController *controller;
@end

@implementation NRMAOnScreenController
@end

// Mutated from viewDidAppear:/viewDidDisappear: and read by the background/foreground handlers. All
// of those are main-thread in practice; the lock is here because "in practice" is not a guarantee
// worth a corrupted array, and it is never held while an event is recorded.
static NSMutableArray<NRMAOnScreenController *> *sOnScreen;
static os_unfair_lock sOnScreenLock = OS_UNFAIR_LOCK_INIT;

static void NRMA_MarkOnScreen(UIViewController *vc) {
    os_unfair_lock_lock(&sOnScreenLock);
    if (sOnScreen == nil) { sOnScreen = [NSMutableArray array]; }
    // Drop any existing entry first, so a repeated appearance moves the controller to the top
    // rather than leaving a stale duplicate lower down. Deallocated entries are swept on the way.
    for (NSInteger i = (NSInteger)sOnScreen.count - 1; i >= 0; i--) {
        UIViewController *held = sOnScreen[(NSUInteger)i].controller;
        if (held == nil || held == vc) {
            [sOnScreen removeObjectAtIndex:(NSUInteger)i];
        }
    }
    NRMAOnScreenController *entry = [NRMAOnScreenController new];
    entry.controller = vc;
    [sOnScreen addObject:entry];
    os_unfair_lock_unlock(&sOnScreenLock);
}

static void NRMA_MarkOffScreen(UIViewController *vc) {
    os_unfair_lock_lock(&sOnScreenLock);
    for (NSInteger i = (NSInteger)sOnScreen.count - 1; i >= 0; i--) {
        UIViewController *held = sOnScreen[(NSUInteger)i].controller;
        if (held == nil || held == vc) {
            [sOnScreen removeObjectAtIndex:(NSUInteger)i];
        }
    }
    os_unfair_lock_unlock(&sOnScreenLock);
}

/// Snapshot of the on-screen controllers, oldest first. Strong references for the duration of the
/// caller's loop, so a controller cannot be deallocated halfway through being reported.
static NSArray<UIViewController *> *NRMA_OnScreenControllers(void) {
    NSMutableArray<UIViewController *> *controllers = [NSMutableArray array];
    os_unfair_lock_lock(&sOnScreenLock);
    for (NRMAOnScreenController *entry in sOnScreen) {
        UIViewController *held = entry.controller;
        if (held) { [controllers addObject:held]; }
    }
    os_unfair_lock_unlock(&sOnScreenLock);
    return controllers;
}

#endif

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

#if !TARGET_OS_WATCH
/*
 * YES when some part of the controller's view is actually visible: it is in a window, neither it nor
 * any ancestor is hidden, and it overlaps the window's bounds.
 *
 * viewDidAppear: alone does not say that. UIKit delivers it to every child of an appearing parent,
 * including one parked off-screen until the user reveals it -- a side-menu drawer constrained to
 * leading = -width. Treated as appeared, such a drawer was reported as visible for as long as its
 * parent was, and as the most recent appearance it became the referrer of whatever appeared next.
 *
 * Alpha is deliberately not consulted: a screen that fades its content in from alpha 0 in
 * viewDidAppear: is being shown, not hidden, and would be dropped.
 */
BOOL NRMA_IsControllerViewOnScreen(UIViewController *vc) {
    UIView *view = vc.viewIfLoaded;
    UIWindow *window = view.window;
    if (view == nil || window == nil) { return NO; }

    for (UIView *node = view; node != nil; node = node.superview) {
        if (node.isHidden) { return NO; }
    }

    CGRect inWindow = [view convertRect:view.bounds toView:nil];
    CGRect visible  = CGRectIntersection(inWindow, window.bounds);
    return !CGRectIsNull(visible) && visible.size.width > 0 && visible.size.height > 0;
}
#endif

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
 * Always names the view. A nil or empty return from the hook falls back to the demangled class
 * name; there is no return value that opts a view out. Nil used to mean "ignore this view", so a
 * hook that computes its name and returns nil when it has nothing better -- the natural shape for
 * an optional-returning Swift method -- silently dropped the screen instead of naming it after its
 * class. Screens are reported or not by the AutomaticMobileViews flag, which is one decision the
 * customer makes once, rather than per view controller in code the agent cannot see.
 */
NS_INLINE NSString *NRMA_ViewNameForController(UIViewController *vc) {
    SEL sel = @selector(nrMobileViewName);
    if ([vc respondsToSelector:sel]) {
        NSString *custom = [(id<_NRMVNameHook>)vc nrMobileViewName];
        // nil or empty: fall through to the class name.
        if (custom.length > 0) return custom;
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

#pragma mark - Automatic SwiftUI screens

/**
 * YES when this controller is a SwiftUI hosting controller and automatic SwiftUI collection is on.
 *
 * The looser of the two gates. Used by viewDidLoad, which must record a construction start
 * *before* the host has a parent -- at that point it cannot yet be known whether the host will
 * turn out to be a navigated-to screen, and a timestamp on a host that never becomes one is
 * harmless.
 */
NS_INLINE BOOL NRMA_IsAutomaticSwiftUIHost(UIViewController *vc) {
    if (![NRMAFlags shouldEnableAutomaticSwiftUIViews]) return NO;
    return [NRMASwiftUIScreenResolver isSwiftUIHost:vc];
}

/**
 * The resolved screen for a SwiftUI host, or nil when this host is not a screen.
 *
 * nil covers every "emit nothing" case the resolver owns: a decorative sub-host such as the one
 * SwiftUI creates for a navigation title, a content type that could not be recovered from inside
 * AnyView, and a view already carrying .NRMobileView(...) -- which owns its own reporting.
 */
NS_INLINE NRMASwiftUIScreen * _Nullable NRMA_SwiftUIScreenForController(UIViewController *vc) {
    if (!NRMA_IsAutomaticSwiftUIHost(vc)) return nil;

    NRMASwiftUIScreen *cached = objc_getAssociatedObject(vc, &kNRSwiftUIScreenKey);
    if (cached) return cached;

    NRMASwiftUIScreen *resolved = [NRMASwiftUIScreenResolver screenFor:vc];
    if (resolved) {
        objc_setAssociatedObject(vc, &kNRSwiftUIScreenKey, resolved,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return resolved;
}

#pragma mark - Swizzled method implementations

static void NRMA_ViewDidLoad(UIViewController *self, SEL _cmd) {
    if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);

    // SwiftUI hosts are excluded by class prefix for the UIKit path, but under automatic SwiftUI
    // collection their construction start is exactly what makes loadTime measurable, so they are
    // let through here. Their class-derived viewName is a generic modifier stack and is not
    // consulted: whether this host is a screen, and what it is called, is decided at appear time
    // once it has a parent.
    if (NRMA_IsAutomaticSwiftUIHost(self)) {
        objc_setAssociatedObject(self, &kNRLoadTimestampKey,
                                 @([NRMAViewContext monotonicNow]),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (NRMA_ShouldSkipClass([self class])) return;

    NSString *viewName  = NRMA_ViewNameForController(self);
    if (NRMA_ShouldSkipViewName(viewName)) return;

    objc_setAssociatedObject(self, &kNRLoadTimestampKey,
                             @([NRMAViewContext monotonicNow]),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void NRMA_ViewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewDidAppear) orig_viewDidAppear(self, _cmd, animated);

    // A SwiftUI host reports as a screen only when the resolver vouches for it. Resolved first
    // because it is what lifts the class-prefix exclusion that would otherwise drop every
    // hosting controller.
    NRMASwiftUIScreen *swiftUIScreen = NRMA_SwiftUIScreenForController(self);

    if (!swiftUIScreen && NRMA_ShouldSkipClass([self class])) return;

    NSString *viewName = swiftUIScreen ? swiftUIScreen.viewName : NRMA_ViewNameForController(self);
    if (NRMA_ShouldSkipViewName(viewName)) return;

    // Appeared, but not where the user can see it. No visit is opened, so its viewDidDisappear: finds
    // nothing to close, and it never sits on the visible stack to be "uncovered" later.
    if (!NRMA_IsControllerViewOnScreen(self)) return;

    CFAbsoluteTime appearTime = [NRMAViewContext monotonicNow];
    objc_setAssociatedObject(self, &kNRAppearTimestampKey,
                             @(appearTime),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *uuid = [[NSUUID UUID] UUIDString];
    // Fresh UUID for this single visible-lifetime instance
    objc_setAssociatedObject(self, &kNRViewInstanceIdKey,
                             uuid,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Read back rather than passed down because viewDidLoad may never have run for this appearance.
    // Read *before* the transition: the load start is part of what the transition records, because
    // it is the origin both the timeToInitialDisplay baseline and every markViewTiming: on this
    // screen resolve against.
    //
    // Absent on every appearance after the first: viewDidLoad fires once per load, and
    // viewDidDisappear clears this key. A screen the user returns to was not rebuilt, so it has
    // nothing to time.
    NSNumber *loadTimestamp = objc_getAssociatedObject(self, &kNRLoadTimestampKey);

    // viewDidLoad → viewDidAppear is an exact construction-to-visible boundary, but only when the
    // view was loaded *because* it was about to be shown. A controller whose `view` was touched
    // early -- a preloaded tab, an eagerly-built container child -- loaded minutes before it
    // appeared, and the interval is an artifact of that, not a slow screen. Above the shared
    // ceiling the agent declines to vouch for it: no loadTime, no baseline row, and marks fall
    // back to the appear time. The absent loadTime is what tells a consumer that happened.
    double loadTimeMs      = 0.0;
    BOOL loadIsMeasurable  = NO;
    if (loadTimestamp) {
        loadTimeMs = [NRMAViewContext millisecondsBetween:loadTimestamp.doubleValue and:appearTime];
        loadIsMeasurable = (loadTimeMs <= kNRMAMaxPlausibleLoadMs);
    }

    // Make this view current in the shared context so it becomes the referrer for the next view
    // and for breadcrumbs recorded while it is visible.
    // The toolkit that observed this view. A resolved SwiftUI host reports "SwiftUI" so its
    // events are indistinguishable from what the .NRMobileView modifier produces for the same
    // screen -- consumers should not be able to tell which producer saw it.
    NSString *platform = swiftUIScreen ? @"SwiftUI" : @"UIKit";

    [[NRMAViewContext sharedInstance] transitionToView:viewName
                                            instanceId:uuid
                                            appearTime:appearTime
                                         loadStartTime:(loadIsMeasurable ? loadTimestamp : nil)
                                              platform:platform];

    // No event is emitted here. One MobileView event is recorded per visit, at
    // viewDidDisappear:, because a visit cannot be described until it has ended -- timeVisible is
    // only knowable then. What an appearance *does* know is captured instead: the referrer below,
    // and the construction start read above (kNRLoadTimestampKey survives until the disappear
    // handler recomputes loadTime from it).
    //
    // Stashed now rather than read at emit time: the transition above just made this view current,
    // so the context's previous view is this appearance's referrer only until the next screen
    // appears.
    NSDictionary *referrer = [[NRMAViewContext sharedInstance] previousViewAttributes];
    objc_setAssociatedObject(self, &kNRReferrerKey,
                             referrer.count > 0 ? referrer : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Enumerable from outside a lifecycle callback, which is what backgrounding needs: it must
    // close out every visit that is still open, and no per-controller callback fires for it.
    NRMA_MarkOnScreen(self);

    // The out-of-the-box baseline, so MobileViewTiming dashboards populate with no customer
    // instrumentation and customer marks such as timeToFullDisplay share its origin. Derived from
    // the load start and appear time the transition above recorded rather than from a number passed
    // in here, so the baseline and those marks cannot end up measured from different instants.
    // No-ops on its own when no construction start was vouched for.
    [[NRMAViewTiming sharedInstance] recordInitialDisplayForCurrentView];
}

/*
 * Ends the visit `vc` is in: records its one MobileView event and drops it from the shared view
 * context's visible stack.
 *
 * Two callers, and the difference between them is why this is a function rather than the body of
 * viewDidDisappear:. The lifecycle callback means "this screen is gone". The background handler
 * means "the app is gone, with this screen still on it" -- the visit has ended either way, and
 * ended at `endTime`, but only the first should stop treating the controller as on screen.
 *
 * A no-op when there is no open visit to end: viewDidAppear: was never observed for this instance
 * (the agent started mid-session, or the view was skipped on appear), or the visit was already
 * closed out by a background flush and no foreground has re-opened it.
 */
static void NRMA_CloseVisit(UIViewController *vc, NRMASwiftUIScreen *swiftUIScreen, CFAbsoluteTime endTime,
                            NRMAViewDeparture departure) {
    CFAbsoluteTime disappearTime = endTime;

    NSNumber *appearTimestamp    = objc_getAssociatedObject(vc, &kNRAppearTimestampKey);
    NSNumber *loadTimestamp      = objc_getAssociatedObject(vc, &kNRLoadTimestampKey);
    NSString *instanceId         = objc_getAssociatedObject(vc, &kNRViewInstanceIdKey);

    if (!appearTimestamp || !instanceId) { return; }

    // viewName: the resolved SwiftUI screen name, or the simple demangled name (or custom
    // override) for UIKit, e.g. "ProductDetailViewController"
    NSString *viewName = swiftUIScreen ? swiftUIScreen.viewName : NRMA_ViewNameForController(vc);

    double timeVisibleMs = [NRMAViewContext millisecondsBetween:appearTimestamp.doubleValue and:disappearTime];

    // loadTime is reported only when there is a trustworthy construction start. This used to fall
    // through to 0.0, which put a real zero into every percentile over loadTime for exactly the
    // appearances that had nothing to measure -- every screen the user returned to, since
    // viewDidLoad fires once per load.
    double loadTimeMs     = 0.0;
    BOOL loadIsMeasurable = NO;
    if (loadTimestamp) {
        loadTimeMs = [NRMAViewContext millisecondsBetween:loadTimestamp.doubleValue and:appearTimestamp.doubleValue];
        loadIsMeasurable = (loadTimeMs <= kNRMAMaxPlausibleLoadMs);
    }

    // viewClass: fully-qualified demangled name, e.g. "MyApp.ProductDetailViewController"
    NSString *viewClass = swiftUIScreen ? swiftUIScreen.viewClass : NRMA_DemangledName([vc class], YES);

    NSDictionary *referrer = objc_getAssociatedObject(vc, &kNRReferrerKey);

    NRMAMobileViewFields *fields = [NRMAMobileViewFields new];
    fields.viewName      = viewName;
    fields.viewClass     = viewClass;
    fields.instanceId    = instanceId;
    fields.uiFramework   = swiftUIScreen ? @"SwiftUI" : @"UIKit";
    fields.timeVisibleMs = @(timeVisibleMs);
    fields.custom        = NRMA_AttributesForController(vc);
    // The referrer this screen appeared from, captured back at viewDidAppear:.
    fields.previousView           = referrer[@"previousView"];
    fields.previousViewInstanceId = referrer[@"previousViewInstanceId"];

    if (loadIsMeasurable) {
        fields.loadTimeMs = @(loadTimeMs);
    } else if (loadTimestamp) {
        fields.loadTimeUnavailable = kNRLoadUnavailableConstructedBeforeAppear;
    } else {
        fields.loadTimeUnavailable = kNRLoadUnavailableNoConstructionObserved;
    }

    [NRMAMobileViewRecorder record:fields];

    // Drop this instance from the visible-view stack. For UIKit this is bookkeeping rather than a
    // fix: viewDidAppear: fires on pop, so the uncovered screen reports a real appearance moments
    // from now, which supersedes anything synthesized here. Keeping the stack accurate matters
    // because a UIKit controller can be what a *SwiftUI* view was covering.
    [[NRMAViewContext sharedInstance] viewDidDisappearNamed:viewName instanceId:instanceId departure:departure];

    // Clear per-instance timing so stale data isn't carried forward. Clearing the appear timestamp
    // is also what marks the visit closed, so a later viewDidDisappear: for a controller already
    // flushed at background finds nothing to report rather than emitting the visit twice.
    //
    // The referrer is deliberately kept: if the app is foregrounded with this screen still up, the
    // re-opened visit was still reached from the same place, and re-reading the context then would
    // name this screen as its own referrer.
    objc_setAssociatedObject(vc, &kNRLoadTimestampKey,   nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &kNRAppearTimestampKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &kNRViewInstanceIdKey,  nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*
 * Starts a new visit for a controller that is still on screen after the app came back.
 *
 * Backgrounding ended the previous visit, and nothing re-announces a screen on the way back in:
 * neither viewDidAppear: nor viewWillAppear: fires when an app is foregrounded, because from
 * UIKit's point of view the screen never went anywhere. Without this the time the user spends on
 * that screen after returning belongs to no visit at all, and the shared context's visible stack
 * has a hole where this screen used to be -- so the next screen to appear would report whatever is
 * left underneath as its referrer.
 *
 * No construction start: nothing was built or laid out, the app was merely resumed. That is the
 * same shape as any other visit with no observed load, so `loadTime` is omitted and the reason
 * recorded rather than a zero being invented.
 */
static void NRMA_ReopenVisit(UIViewController *vc, NRMASwiftUIScreen *swiftUIScreen, CFAbsoluteTime startTime) {
    // Only re-open what a background flush closed. A controller whose visit is somehow still open
    // must be left alone: overwriting its appear timestamp would strand that visit -- no event for
    // it, and its entry stuck on the visible stack for another disappearance to resurrect.
    if (objc_getAssociatedObject(vc, &kNRAppearTimestampKey) != nil) { return; }

    NSString *viewName = swiftUIScreen ? swiftUIScreen.viewName : NRMA_ViewNameForController(vc);
    if (NRMA_ShouldSkipViewName(viewName)) { return; }

    NSString *uuid = [[NSUUID UUID] UUIDString];
    objc_setAssociatedObject(vc, &kNRAppearTimestampKey, @(startTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &kNRViewInstanceIdKey,  uuid,        OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[NRMAViewContext sharedInstance] transitionToView:viewName
                                           instanceId:uuid
                                           appearTime:startTime
                                        loadStartTime:nil
                                             platform:(swiftUIScreen ? @"SwiftUI" : @"UIKit")];
}

/*
 * Why a controller's viewDidDisappear: fired: it is leaving (popped, or dismissed -- itself or any
 * container above it), or it is only covered (pushed past, under a full-screen presentation, a tab
 * switched away from).
 *
 * The shared context needs the difference because this callback arrives *before* the next screen's
 * viewDidAppear:. Treating every disappearance of the top screen as a return to what was beneath it
 * made the screen beneath the referrer of the very push that covered the departing one. Inside a
 * SwiftUI NavigationView the outer host is always beneath, so every pushed screen, and every return
 * to one, named the enclosing list as its previousView.
 */
static NRMAViewDeparture NRMA_DepartureOf(UIViewController *vc) {
    for (UIViewController *node = vc; node != nil; node = node.parentViewController) {
        if (node.isMovingFromParentViewController || node.isBeingDismissed) {
            return NRMAViewDepartureLeaving;
        }
    }
    return NRMAViewDepartureCovered;
}

static void NRMA_ViewDidDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewDidDisappear) orig_viewDidDisappear(self, _cmd, animated);

    // Read from the cache viewDidAppear: populated, so the event names the screen as it was when
    // it appeared even if the host's content has since changed.
    NRMASwiftUIScreen *swiftUIScreen = NRMA_SwiftUIScreenForController(self);

    if (!swiftUIScreen && NRMA_ShouldSkipClass([self class])) return;

    // Off the on-screen list before the close-out, and unconditionally: a controller that
    // disappeared while the app was backgrounded has no visit left to close, but it must still not
    // be re-opened when the app comes back.
    NRMA_MarkOffScreen(self);

    NRMA_CloseVisit(self, swiftUIScreen, [NRMAViewContext monotonicNow], NRMA_DepartureOf(self));

    // The referrer outlives a background-flushed visit (see NRMA_CloseVisit), but not a real
    // disappearance -- the next appearance of this controller gets its own.
    objc_setAssociatedObject(self, &kNRReferrerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        NRLOG_AGENT_INFO(@"[MobileViews] UIViewController lifecycle tracking started.");
#endif

    });
}

- (void)flushOpenVisitsOnBackground {
#if !TARGET_OS_WATCH
    // One instant for every view, so two screens that were on screen together report the same end.
    CFAbsoluteTime now = [NRMAViewContext monotonicNow];

    // Newest first: closing the topmost screen first means each close-out uncovers the one beneath
    // it in the shared context's visible stack, which is the same order a user leaving these screens
    // would produce. Closing bottom-up would make a screen the user is not looking at current.
    for (UIViewController *vc in [NRMA_OnScreenControllers() reverseObjectEnumerator]) {
        // Unknown, not Covered: the visible stack has to unwind top-down as each screen is closed.
        NRMA_CloseVisit(vc, NRMA_SwiftUIScreenForController(vc), now, NRMAViewDepartureUnknown);
    }
    // The controllers stay on the on-screen list: they are still on screen, and the app coming back
    // must be able to re-open them.
#endif
}

- (void)reopenOpenVisitsOnForeground {
#if !TARGET_OS_WATCH
    CFAbsoluteTime now = [NRMAViewContext monotonicNow];

    // Oldest first, the mirror image of the flush: the last one pushed is the one the user is
    // looking at, and it must end up on top of the visible stack and current.
    for (UIViewController *vc in NRMA_OnScreenControllers()) {
        NRMA_ReopenVisit(vc, NRMA_SwiftUIScreenForController(vc), now);
    }
#endif
}

@end
