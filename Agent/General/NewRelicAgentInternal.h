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
@property(atomic, strong) NRMAHandledExceptions* handledExceptionsController;
@property(atomic, strong) NRMAUserActionFacade* gestureFacade;
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

- (void) applicationWillEnterForeground;
- (void) sessionStartInitialization;
+ (NewRelicAgentInternal* _Nullable) sharedInstance;

- (NSString*) currentSessionId;

// Returns whether or not we should be collecting HTTP errors. Exposed for ASI support.
- (BOOL) collectNetworkErrors;
+ (BOOL) harvestNow;

// URLTransformer
+ (void)setURLTransformer:(NRMAURLTransformer *)urlTransformer;
+ (NRMAURLTransformer *)getURLTransformer;

- (void) sessionReplayStart;

- (void) sessionReplayDisabled;

- (void) sessionReplayEndSession;

- (BOOL) isSessionReplaySampled;

- (BOOL) isSessionReplayEnabled;

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
