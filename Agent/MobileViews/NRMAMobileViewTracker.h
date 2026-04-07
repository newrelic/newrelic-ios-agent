//
//  NRMAMobileViewTracker.h
//  NewRelicAgent
//
//  POC: MobileViews feature — automatic UIViewController lifecycle tracking.
//  Emits "MobileView" custom events with timing and identity attributes.
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * NRMAMobileViewTracker swizzles UIViewController lifecycle methods to automatically
 * record MobileView events.
 *
 * Attributes emitted on each MobileView event:
 *   viewClass       (NSString) — ObjC/Swift class name of the view controller
 *   viewName        (NSString) — Display name; overridable via NRMobileViewNameProvider protocol
 *   viewInstanceId  (NSString) — UUID unique to this single visible lifetime of the view
 *   restarted       (NSNumber/BOOL) — NO on first appearance, YES on subsequent appearances
 *   loadTime        (NSNumber/double, ms) — viewDidLoad → viewDidAppear (0 if viewDidLoad not observed)
 *   timeVisible     (NSNumber/double, ms) — viewDidAppear → viewDidDisappear
 */
@interface NRMAMobileViewTracker : NSObject

+ (instancetype)sharedInstance;

/**
 * Installs UIViewController swizzles. Call once during agent startup.
 * Safe to call multiple times — guarded by dispatch_once internally.
 */
- (void)start;

@end

/**
 * UIViewController subclasses may implement this protocol to provide a custom
 * viewName for MobileView events, overriding the default class-name-based name.
 */
@protocol NRMobileViewNameProvider <NSObject>
@optional
- (NSString *)nrMobileViewName;
@end

NS_ASSUME_NONNULL_END
