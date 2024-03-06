//
// Created by Bryce Buchanan on 5/18/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAFlags.h"
#import "NRConstants.h"
#import "NRMAMetric.h"
#import "NRMATaskQueue.h"
#import "NRMASupportMetricHelper.h"

@implementation NRMAFlags

static NRMAFeatureFlags __flags;
static BOOL __saltDeviceUUID = NO;

static NSString* __deviceIdentifierReplacement = NULL;

+ (void) enableFeatures:(NRMAFeatureFlags)featureFlags {
    NRMAFeatureFlags flags = [self featureFlags];
    __flags = flags | featureFlags;

    [NRMASupportMetricHelper enqueueFeatureFlagMetric:true features:featureFlags];
}

+ (void) disableFeatures:(NRMAFeatureFlags)featureFlags {
    NRMAFeatureFlags flags = [self featureFlags];
    __flags = flags & ~featureFlags;

    [NRMASupportMetricHelper enqueueFeatureFlagMetric:false features:featureFlags];
}

+ (NRMAFeatureFlags) featureFlags
{
    static dispatch_once_t defaultFeatureToken;
    dispatch_once(&defaultFeatureToken,
                  ^{
                      //enable default features here
                      __flags = __flags |
                              NRFeatureFlag_CrashReporting |
                              NRFeatureFlag_InteractionTracing |
                              NRFeatureFlag_NSURLSessionInstrumentation |
                              NRFeatureFlag_HttpResponseBodyCapture |
                              NRFeatureFlag_DefaultInteractions |
                              NRFeatureFlag_WebViewInstrumentation |
                              NRFeatureFlag_HandledExceptionEvents |
                              NRFeatureFlag_NetworkRequestEvents | 
                              NRFeatureFlag_RequestErrorEvents |
                              NRFeatureFlag_DistributedTracing |
                              NRFeatureFlag_AppStartMetrics;
                  });
    return __flags;
}

+ (void) setFeatureFlags:(NRMAFeatureFlags)featureflags {
    //for testing only
    [self featureFlags]; //to prime the flags.
    __flags = featureflags;
}

+ (BOOL) shouldSaltDeviceUUID {
    return __saltDeviceUUID;
}

+ (void) setSaltDeviceUUID:(BOOL)enable {
    __saltDeviceUUID = enable;
}

#pragma mark Replacement of Device Identifier

/// Returns YES if device identifier should be replaced.
+ (BOOL) shouldReplaceDeviceIdentifier {
    return __deviceIdentifierReplacement != nil;
}

/// Allows device identifier to be replaced with a String `identifier`
/// NOTE: Whitespace and new lines will be trimmed.
/// If the trimmed device identifier replacement is blank then "0" will be used.
/// @param identifier  pass replacement String. pass NULL to stop replacing.
+ (void) setShouldReplaceDeviceIdentifier:(NSString*)identifier {
    if (identifier == nil) {
        __deviceIdentifierReplacement = nil;
        return;
    }
    NSString *trimmedString = [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    __deviceIdentifierReplacement = trimmedString.length > 0 ? trimmedString : @"0";
    if (trimmedString.length > kNRDeviceIDReplacementMaxLength) {
        __deviceIdentifierReplacement = [trimmedString substringWithRange:NSMakeRange(0, kNRDeviceIDReplacementMaxLength)];
    }
}

+ (NSString*) replacementDeviceIdentifier {

    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRMAUUIDOverridden
                                                    value:@1
                                                    scope:@""]];
    return __deviceIdentifierReplacement;
}

#pragma mark END Replacement of Device Identifier

+ (BOOL) shouldEnableHandledExceptionEvents {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_HandledExceptionEvents) != 0;
}

+ (BOOL) shouldEnableGestureInstrumentation {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_GestureInstrumentation) != 0;
}

+ (BOOL) shouldEnableNSURLSessionInstrumentation {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_NSURLSessionInstrumentation) != 0;
}

+ (BOOL) shouldEnableExperimentalNetworkingInstrumentation {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_ExperimentalNetworkingInstrumentation) != 0;
}

+ (BOOL) shouldEnableSwiftInteractionTracing {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_SwiftInteractionTracing) != 0;
}

+ (BOOL) shouldEnableInteractionTracing {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_InteractionTracing) != 0;
}

+ (BOOL) shouldEnableCrashReporting {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_CrashReporting) != 0;
}

+ (BOOL) shouldEnableDefaultInteractions {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_DefaultInteractions) != 0;
}
+ (BOOL) shouldEnableHttpResponseBodyCapture {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_HttpResponseBodyCapture) != 0;
}

+ (BOOL) shouldEnableWebViewInstrumentation {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_WebViewInstrumentation) != 0;
}

+ (BOOL) shouldEnableRequestErrorEvents {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_RequestErrorEvents) != 0;
}

+ (BOOL) shouldEnableNetworkRequestEvents {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_NetworkRequestEvents) != 0;
}

+ (BOOL) shouldEnableDistributedTracing {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_DistributedTracing) != 0;
}

+ (BOOL) shouldEnableAppStartMetrics {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_AppStartMetrics) != 0;
}

+ (BOOL) shouldEnableFedRampSupport {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_FedRampEnabled) != 0;
}

+ (BOOL) shouldEnableSwiftAsyncURLSessionSupport {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_SwiftAsyncURLSessionSupport) != 0;
}

+ (BOOL) shouldEnableOfflineStorage {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_OfflineStorage) != 0;
}

+ (BOOL) shouldEnableLogReporting {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_LogReporting) != 0;
}
+ (BOOL) shouldEnableNewEventSystem {
    return ([NRMAFlags featureFlags] & NRFeatureFlag_NewEventSystem) != 0;
}
+ (NSArray<NSString*>*) namesForFlags:(NRMAFeatureFlags)flags {
    NSMutableArray *retArray = [NSMutableArray array];
    if ((flags & NRFeatureFlag_InteractionTracing) == NRFeatureFlag_InteractionTracing) {
        [retArray addObject:@"InteractionTracing"];
    }
    if ((flags & NRFeatureFlag_SwiftInteractionTracing) == NRFeatureFlag_SwiftInteractionTracing) {
        [retArray addObject:@"SwiftInteractionTracing"];
    }
    if ((flags & NRFeatureFlag_CrashReporting) == NRFeatureFlag_CrashReporting) {
        [retArray addObject:@"CrashReporting"];
    }
    if ((flags & NRFeatureFlag_NSURLSessionInstrumentation) == NRFeatureFlag_NSURLSessionInstrumentation) {
        [retArray addObject:@"NSURLSessionInstrumentation"];
    }
    if ((flags & NRFeatureFlag_HttpResponseBodyCapture) == NRFeatureFlag_HttpResponseBodyCapture) {
        [retArray addObject:@"HttpResponseBodyCapture"];
    }
    if ((flags & NRFeatureFlag_WebViewInstrumentation) == NRFeatureFlag_WebViewInstrumentation) {
        [retArray addObject:@"WebViewInstrumentation"];
    }
    if ((flags & NRFeatureFlag_RequestErrorEvents) == NRFeatureFlag_RequestErrorEvents) {
        [retArray addObject:@"RequestErrorEvents"];
    }
    if ((flags & NRFeatureFlag_NetworkRequestEvents) == NRFeatureFlag_NetworkRequestEvents) {
        [retArray addObject:@"NetworkRequestEvents"];
    }
    if ((flags & NRFeatureFlag_HandledExceptionEvents) == NRFeatureFlag_HandledExceptionEvents) {
        [retArray addObject:@"HandledExceptionEvents"];
    }
    if ((flags & NRFeatureFlag_DefaultInteractions) == NRFeatureFlag_DefaultInteractions) {
        [retArray addObject:@"DefaultInteractions"];
    }
    if ((flags & NRFeatureFlag_ExperimentalNetworkingInstrumentation) == NRFeatureFlag_ExperimentalNetworkingInstrumentation) {
        [retArray addObject:@"ExperimentalNetworkingInstrumentation"];
    }
    if ((flags & NRFeatureFlag_DistributedTracing) == NRFeatureFlag_DistributedTracing) {
        [retArray addObject:@"DistributedTracing"];
    }
    if ((flags & NRFeatureFlag_GestureInstrumentation) == NRFeatureFlag_GestureInstrumentation) {
        [retArray addObject:@"GestureInstrumentation"];
    }
    if ((flags & NRFeatureFlag_AppStartMetrics) == NRFeatureFlag_AppStartMetrics) {
        [retArray addObject:@"AppStartMetrics"];
    }
    if ((flags & NRFeatureFlag_FedRampEnabled) == NRFeatureFlag_FedRampEnabled) {
        [retArray addObject:@"FedRamp Enabled"];
    }
    if ((flags & NRFeatureFlag_SwiftAsyncURLSessionSupport) == NRFeatureFlag_SwiftAsyncURLSessionSupport) {
        [retArray addObject:@"SwiftAsyncURLSessionSupport"];
    }
    if ((flags & NRFeatureFlag_OfflineStorage) == NRFeatureFlag_OfflineStorage) {
        [retArray addObject:@"OfflineStorage"];
    }
    if ((flags & NRFeatureFlag_LogReporting) == NRFeatureFlag_LogReporting) {
        [retArray addObject:@"LogReporting"];
    }
    if ((flags & NRFeatureFlag_NewEventSystem) == NRFeatureFlag_NewEventSystem) {
        [retArray addObject:@"NewEventSystem"];
    }
    return retArray;
}

@end
