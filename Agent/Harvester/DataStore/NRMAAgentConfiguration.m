//
//  NRMAAgentConfiguration.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAgentConfiguration.h"
#import "NRMAApplicationInformation.h"
#import "NRMADeviceInformation.h"
#import "NewRelicInternalUtils.h"
#import "NRMAExceptionhandlerConstants.h"
#import "NRMAAppToken.h"
#import "NRMAFlags.h"
#import "NRLogger.h"

static NSString* __NRMA__customAppVersionString = nil;
static NSString* __NRMA__customAppBuildString = nil;
static NRMAApplicationPlatform __NRMA__applicationPlatform = NRMAPlatform_Native;
static NSString* __NRMA__applicationPlatformVersion = nil;

// Default max event buffer time is 1 minute (60 seconds).
static NSUInteger __NRMA__maxEventBufferTime = 60;
static NSUInteger __NRMA__maxEventBufferSize = 1000;
static NSUInteger __NRMA__maxOfflineStorageSize = 100000000; // 100 mb

@implementation NRMAAgentConfiguration

+ (void)setApplicationVersion:(NSString *)versionString
{
    __NRMA__customAppVersionString = versionString;
}
+ (void)setApplicationBuild:(NSString *)buildString
{
    __NRMA__customAppBuildString = buildString;
}

+(void) setPlatform:(NRMAApplicationPlatform)platform {
    __NRMA__applicationPlatform = platform;
}
+ (void) setPlatformVersion:(NSString*)platformVersion
{
    __NRMA__applicationPlatformVersion = platformVersion;
}

+ (void) setMaxEventBufferTime:(NSUInteger)seconds {
    __NRMA__maxEventBufferTime = seconds;
    
}
+ (NSUInteger) getMaxEventBufferTime {
    return __NRMA__maxEventBufferTime;
}

+ (void) setMaxEventBufferSize:(NSUInteger)size {
    __NRMA__maxEventBufferSize = size;
}
+ (NSUInteger) getMaxEventBufferSize {
    return __NRMA__maxEventBufferSize;
}

+ (void) setMaxOfflineStorageSize:(NSUInteger)megabytes {
    __NRMA__maxOfflineStorageSize = megabytes;
}

+ (NSUInteger) getMaxOfflineStorageSize {
    return __NRMA__maxOfflineStorageSize;
}

static NSMutableArray * __NRMA__session_replay_maskedClassNames;
+ (NSMutableArray*) local_session_replay_maskedClassNames
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __NRMA__session_replay_maskedClassNames = [NSMutableArray array];
    });

    return (__NRMA__session_replay_maskedClassNames);
}

static NSMutableArray * __NRMA__session_replay_unmaskedClassNames;
+ (NSMutableArray*) local_session_replay_unmaskedClassNames
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __NRMA__session_replay_unmaskedClassNames = [NSMutableArray array];
    });

    return (__NRMA__session_replay_unmaskedClassNames);
}

static NSMutableArray * __NRMA__session_replay_maskedAccessibilityIdentifiers;
+ (NSMutableArray*) local_session_replay_maskedAccessibilityIdentifiers
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __NRMA__session_replay_maskedAccessibilityIdentifiers = [NSMutableArray array];
    });

    return (__NRMA__session_replay_maskedAccessibilityIdentifiers);
}

static NSMutableArray * __NRMA__session_replay_unmaskedAccessibilityIdentifiers;
+ (NSMutableArray*) local_session_replay_unmaskedAccessibilityIdentifiers
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __NRMA__session_replay_unmaskedAccessibilityIdentifiers = [NSMutableArray array];
    });

    return (__NRMA__session_replay_unmaskedAccessibilityIdentifiers);
}

- (id) initWithAppToken:(NRMAAppToken*)token
       collectorAddress:(NSString*)collectorHost
           crashAddress:(NSString*)crashHost {
    self = [super init];
    if (self) {

        _applicationToken = token;

        [self setCollectorHost:collectorHost];
        [self setCrashCollectorHost:crashHost];
        [self setLoggingURL];
        
        // Default mode
        _sessionReplayMode = @"OFF";
        
        if ([[NSProcessInfo processInfo] environment][@"UITesting"]) {
            _useSSL = NO;
        } else {
            _useSSL = YES;
        }
    }
    return self;
}

/*
 * behavior:
 *  if custom host is set, use custom host.
 *  otherwise, if region-specific apptoken is detected, then use region specific host.
 *  else, use default host.
 */
- (void) setCollectorHost:(NSString*)host {
    if (host) {
        _collectorHost = host;
        _loggingHost = host;
    } else {
        if ([NRMAFlags shouldEnableFedRampSupport]) {
            _collectorHost = kNRMA_FEDRAMP_COLLECTOR_HOST;
        } else if (self.applicationToken.regionCode.length) {
            _collectorHost = [NSString stringWithFormat:kNRMA_REGION_SPECIFIC_COLLECTOR_HOST,self.applicationToken.regionCode];
        } else {
            _collectorHost = kNRMA_DEFAULT_COLLECTOR_HOST;
        }
    }
}

/* behavior:
 *  if custom host is set, use custom host.
 *  otherwise, if region-specific apptoken is detected, then use region specific host.
 *  else, use default host.
 */
- (void) setCrashCollectorHost:(NSString*)host {
    if (host) {
         _crashCollectorHost  = host;
    } else {
        if ([NRMAFlags shouldEnableFedRampSupport]) {
            _crashCollectorHost = KNRMA_FEDRAMP_CRASH_COLLECTOR_HOST;
        } else if (self.applicationToken.regionCode.length) {
            _crashCollectorHost = [NSString stringWithFormat:kNRMA_REGION_SPECIFIC_CRASH_HOST,self.applicationToken.regionCode];
        } else {
            _crashCollectorHost = kNRMA_DEFAULT_CRASH_COLLECTOR_HOST;
        }
    }
}

- (void) setLoggingURL {
    if (_loggingHost) {
        _loggingURL = _loggingHost;
    }
    else if (self.applicationToken.regionCode.length) {
        _loggingURL = [NSString stringWithFormat:kNRMA_REGION_SPECIFIC_LOGGING_HOST,self.applicationToken.regionCode];
    }
    else if ([NRMAFlags shouldEnableFedRampSupport]) {
        if ([self.collectorHost isEqualToString:@"staging-mobile-collector.newrelic.com"]) {
            _loggingURL = kNRMA_STAGING_FEDRAMP_LOGGING_HOST;
        }
        else {
            _loggingURL = kNRMA_FEDRAMP_LOGGING_HOST;
        }
    }
    else if ([self.collectorHost isEqualToString:@"staging-mobile-collector.newrelic.com"]) {
        _loggingURL = kNRMA_STAGING_LOGGING_HOST;
    }
    else {
        _loggingURL = kNRMA_DEFAULT_LOGGING_HOST;
    }
    _sessionReplayURL = [_loggingURL stringByAppendingFormat:@"/mobile/blobs"];
    _loggingURL = [_loggingURL stringByAppendingFormat:@"/mobile/logs"];
    // since setLoggingURL is always called we can make the session replay url here.

    NSString* logURL = [NSString stringWithFormat:@"%@%@", @"https://", _loggingURL];
    
    [NRLogger setLogURL:logURL];
    [NRLogger setLogIngestKey:self.applicationToken.value];
}

+ (NRMAConnectInformation*) connectionInformation
{
    NSString* appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"];
    if (!appName.length) {
        @throw [NSException exceptionWithName:@"NRMAMissingBundleDescriptor" reason:@"CFBundleExecutable is not set" userInfo:nil];
    }

    NSString* appVersion = __NRMA__customAppVersionString;
    NSString* buildNumber = __NRMA__customAppBuildString;
    if (! appVersion.length) {
        appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
        if (!buildNumber.length) {
            buildNumber = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
        }
    }
    if (!appVersion.length) {
        appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    }
    if (!appVersion.length) {
        @throw [NSException exceptionWithName:@"NRMAMissingBundleDescriptor" reason:@"Neither CFBundleShortVersionString nor CFBundleVersion is set" userInfo:nil];
    }

    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID.length) {
        @throw [NSException exceptionWithName:@"NRMAMissingBundleDescriptor" reason:@"CFBundleIdentifier is not set" userInfo:nil];
    }

    NRMAApplicationInformation* appInfo = [[NRMAApplicationInformation alloc] initWithAppName:appName
                                                                               appVersion:appVersion
                                                                                 bundleId:bundleID];
    appInfo.appBuild = buildNumber;

    NRMADeviceInformation* devInfo = [[NRMADeviceInformation alloc] init];
    devInfo.osName = [NewRelicInternalUtils osName];
    devInfo.osVersion = [NewRelicInternalUtils osVersion];
    devInfo.manufacturer = @"Apple Inc.";
    devInfo.model = [NewRelicInternalUtils deviceModel];
    devInfo.agentName = [NewRelicInternalUtils agentName];
    devInfo.agentVersion = [NewRelicInternalUtils agentVersion];
    devInfo.deviceId = [NewRelicInternalUtils deviceId];
    devInfo.platform = __NRMA__applicationPlatform;
    devInfo.platformVersion = __NRMA__applicationPlatformVersion;
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    connectionInformation.applicationInformation = appInfo;
    connectionInformation.deviceInformation = devInfo;
    
    return connectionInformation;
}

+ (BOOL)addLocalMaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        [[NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers] addObject:identifier];
        NRLOG_AGENT_VERBOSE(@"Added masked accessibility identifier: %@", identifier);
        return true;
    }
    return false;
}

+ (BOOL)addLocalUnmaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        [[NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers] addObject:identifier];
        NRLOG_AGENT_VERBOSE(@"Added unmasked accessibility identifier: %@", identifier);
        return true;
    }
    return false;
}

+ (BOOL)addLocalMaskedClassName:(NSString *)className {
    if (className.length > 0) {
        [[NRMAAgentConfiguration local_session_replay_maskedClassNames] addObject:className];
        NRLOG_AGENT_VERBOSE(@"Added masked class name: %@", className);
        return true;
    }
    return false;
}

+ (BOOL)addLocalUnmaskedClassName:(NSString *)className {
    if (className.length > 0) {
        [[NRMAAgentConfiguration local_session_replay_unmaskedClassNames] addObject:className];
        NRLOG_AGENT_VERBOSE(@"Added unmasked class name: %@", className);
        return true;
    }
    return false;
}


@end
