//
//  NewRelicAgentInternal.h
//  NewRelicAgent
//
//  Created by Saxon D'Aubin on 6/12/12.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewRelicFeatureFlags.h"
#import "NRMAMeasurements.h"
#import "NRMAHandledExceptions.h"
#import "NRMAUserActionFacade.h"
#import "NRMAURLTransformer.h"
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif
#if !TARGET_OS_WATCH
#import <BackgroundTasks/BackgroundTasks.h>
#endif
// Keys used for harvester data request.
#define NEW_RELIC_APP_VERSION_HEADER_KEY        @"X-NewRelic-App-Version"
#define NEW_RELIC_OS_NAME_HEADER_KEY            @"X-NewRelic-OS-Name"

// Constants for user settings keys.
#define NEWRELIC_CROSS_PROCESS_ID_SETTINGS_KEY              @"NewRelicCrossProcessId"
#define NEWRELIC_DATA_TOKEN_SETTINGS_KEY                    @"NewRelicDataToken"
#define NEWRELIC_SERVER_TIMESTAMP_SETTINGS_KEY              @"NewRelicServerTimestamp"
#define NEWRELIC_HARVEST_INTERVAL_SETTINGS_KEY              @"NewRelicHarvestInterval"

#define NEWRELIC_AGENT_DISABLED_VERSION_KEY @"NewRelicAgentDisabledVersion"

NS_ASSUME_NONNULL_BEGIN

// Defines the internal agent api.
@interface NewRelicAgentInternal : NSObject

@property (nonatomic, readonly, assign) BOOL enabled;
@property(atomic, strong, nullable) NRMAAnalytics* analyticsController;
@property(atomic, strong, nullable) NRMAHandledExceptions* handledExceptionsController;
@property(atomic, strong, nullable) NRMAUserActionFacade* gestureFacade;
@property(atomic, strong, nullable) NSString* userId;
@property(assign) double sampleSeed;
@property(assign) double sessionReplaySampleSeed;
@property(assign) double sessionReplayErrorSampleSeed;

// Track the total number of successful network requests logged by the agent
@property (nonatomic, readonly, assign) NSUInteger lifetimeRequestCount;

// Track the total number of failed network requests logged by the agent
@property (nonatomic, readonly, assign) NSUInteger lifetimeErrorCount;

@property (atomic, readonly, strong) NRMAAgentConfiguration *agentConfiguration;

@property (nonatomic, assign) BOOL isShutdown;

#if TARGET_OS_WATCH
@property (nonatomic, readonly, assign) WKApplicationState currentApplicationState;
#else
@property (nonatomic, readonly, assign) UIApplicationState currentApplicationState;
#endif
+ (void)shutdown;

+ (void)startWithApplicationToken:(NSString*)appToken
              andCollectorAddress:( NSString* _Nullable )CollectorUrl;

+ (void)startWithApplicationToken:(NSString*)appToken
              andCollectorAddress:(NSString* _Nullable )CollectorUrl
         andCrashCollectorAddress:(NSString* _Nullable )crashCollectorUrl;

- (NSDate*) getAppSessionStartDate;
- (NSString* _Nullable) getUserId;
- (void) setMaxEventBufferTime:(unsigned int)seconds;
- (void) setMaxEventPoolSize:(unsigned int)size;

- (void) applicationWillEnterForeground;
- (void) sessionStartInitialization;
- (void) startNewSessionForUserId:(NSString* _Nullable)userId;
+ (NewRelicAgentInternal* _Nullable) sharedInstance;

// Explicitly nullable: this sits inside the NS_ASSUME_NONNULL region above, so leaving it
// unannotated promised a non-nil result that the implementation cannot keep. It returns
// [self agentConfiguration].sessionIdentifier, which is only assigned in -onSessionStart and is
// therefore nil until a session begins. Swift trusts the annotation, so under the implicit
// nonnull a nil came back across the bridge as a seemingly valid String rather than as nil.
- (NSString* _Nullable) currentSessionId;

// Returns whether or not we should be collecting HTTP errors. Exposed for ASI support.
- (BOOL) collectNetworkErrors;
+ (BOOL) harvestNow;

- (void) checkAndHandleSessionTimeout;

// URLTransformer
+ (void)setURLTransformer:(NRMAURLTransformer *)urlTransformer;
+ (NRMAURLTransformer *)getURLTransformer;

- (void) sessionReplayStart;

- (void) sessionReplayDisabled;

- (void) sessionReplayEndSession;

// Logging Collection - handles sampling check and log upload
- (void) uploadLogsIfSampled;

- (BOOL) isSessionReplaySampled;
- (BOOL) isSessionReplayErrorSampled;

- (BOOL) isSessionReplayEnabled;

#if TARGET_OS_IOS
// JS ERROR SECTION
//
// Records a JavaScript error through the agent's JS error controller, returning NO when that
// controller has not been initialized (JS error events disabled by feature flag, or the agent
// has not started). The caller is responsible for its own shutdown and feature-flag policy;
// this only owns the controller interaction.
//
// Declared purely in Foundation types on purpose. The controller is a Swift type, and naming a
// Swift type in this header does not work: Clang builds the ObjC half as its own module with no
// visibility into the Swift half, so the type stays incomplete and the Swift importer drops the
// declaration entirely — which is what previously forced Swift callers to reach the controller
// by KVC. Keeping the Swift type confined to the .m is the same approach SessionReplayManager
// already uses.
- (BOOL) recordJavascriptErrorWithName:(NSString*)name
                               message:(NSString*)message
                            stackTrace:(NSString*)stackTrace
                               isFatal:(BOOL)isFatal
                  additionalAttributes:(NSDictionary* _Nullable)additionalAttributes;
#endif

// SESSION REPLAY SECTION Methods to manage masked elements for SessionReplay

// Masked section

// Masked Accessibility Identifiers
- (BOOL)isAccessibilityIdentifierMasked:(NSString *)identifier;

// Masked Classes
- (BOOL)isClassNameMasked:(NSString *)className;

// Unmasked section

// Unmasked Accessibility Identifiers
- (BOOL)isAccessibilityIdentifierUnmasked:(NSString *)identifier;

// Unmasked Classes
- (BOOL)isClassNameUnmasked:(NSString *)className;


// END SESSION REPLAY SECTION End Methods to manage masked elements for SessionReplay


// SESSION REPLAY SECTION Methods to start and pause SessionReplay

// Start a session replay recording
- (BOOL) recordReplay;

// Pause a session replay recording
- (BOOL) pauseReplay;
// Notify Session Replay of an error
- (void)sessionReplayOnError:(NSError *_Nullable)error;

// END SESSION REPLAY SECTION Methods to start and pause SessionReplay

@end

/*
 Categories that swizzle methods to intercept method calls implement this protocol.  The
 initializeInstrumentation method of NewRelicAgentInternal calls NewRelicInitializeInstrumentation
 on each category.
 */
@protocol Instrumentation <NSObject>


// Initializes method patching (swizzling) in a category.
+(BOOL)NewRelicInitializeInstrumentation;


@end
NS_ASSUME_NONNULL_END
