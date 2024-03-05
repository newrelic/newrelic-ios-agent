//
// Created by Bryce Buchanan on 5/18/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewRelicFeatureFlags.h"

@interface NRMAFlags : NSObject
+ (void) enableFeatures:(NRMAFeatureFlags)featureFlags;

+ (void) disableFeatures:(NRMAFeatureFlags)featureFlags;

+ (NRMAFeatureFlags) featureFlags;

+ (void) setFeatureFlags:(NRMAFeatureFlags)featureflags;

+ (BOOL) shouldEnableHandledExceptionEvents;

+ (BOOL) shouldEnableGestureInstrumentation;

+ (BOOL) shouldEnableNSURLSessionInstrumentation;

+ (BOOL) shouldEnableExperimentalNetworkingInstrumentation;

+ (BOOL) shouldEnableSwiftInteractionTracing;

+ (BOOL) shouldEnableInteractionTracing;

+ (BOOL) shouldEnableCrashReporting;

+ (BOOL) shouldEnableDefaultInteractions;

+ (BOOL) shouldEnableHttpResponseBodyCapture;

+ (BOOL) shouldEnableWebViewInstrumentation;

+ (BOOL) shouldEnableRequestErrorEvents;

+ (BOOL) shouldEnableNetworkRequestEvents;

+ (BOOL) shouldEnableDistributedTracing;

+ (BOOL) shouldEnableAppStartMetrics;

+ (BOOL) shouldEnableFedRampSupport;

+ (BOOL) shouldEnableSwiftAsyncURLSessionSupport;

+ (BOOL) shouldEnableLogReporting;

+ (BOOL) shouldEnableOfflineStorage;

+ (BOOL) shouldEnableNewEventSystem;

+ (BOOL) shouldEnableBackgroundInstrumentation;

+ (NSArray<NSString*>*) namesForFlags:(NRMAFeatureFlags)flags;

// Private Setting
// Device Identifier Salting
// private settings only for VW (jira:MOBILE-6635)
+ (void) setSaltDeviceUUID:(BOOL)enable;
+ (BOOL) shouldSaltDeviceUUID;

// Private Setting
// Device Identifier Replacement
+ (void) setShouldReplaceDeviceIdentifier:(NSString*)identifier;
+ (BOOL) shouldReplaceDeviceIdentifier;
+ (NSString*) replacementDeviceIdentifier;

@end
