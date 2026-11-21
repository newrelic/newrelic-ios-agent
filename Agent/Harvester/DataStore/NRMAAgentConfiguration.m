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
// An explicit setPlatform:/setPlatformVersion: call always wins over the framework plist.
static BOOL __NRMA__applicationPlatformExplicit = NO;
static BOOL __NRMA__applicationPlatformVersionExplicit = NO;

// Every hybrid plugin (Flutter, React Native, ...) ships a NewRelicHybrid.plist in its resources so the agent
// can learn the framework even when the app starts the agent natively before any plugin code runs.
// Keys: ApplicationFramework (an NRMAApplicationPlatform name, e.g. "Flutter") and
// ApplicationFrameworkVersion (the plugin version).
static NSString* const kNRMAHybridPlistName = @"NewRelicHybrid";
static NSString* const kNRMAHybridPlistFrameworkKey = @"ApplicationFramework";
static NSString* const kNRMAHybridPlistVersionKey = @"ApplicationFrameworkVersion";

static NSDictionary<NSString*, NSNumber*>* NRMAPlatformsByName(void) {
    return @{kNRMAPlatformString_Cordova:      @(NRMAPlatform_Cordova),
             kNRMAPlatformString_PhoneGap:     @(NRMAPlatform_PhoneGap),
             kNRMAPlatformString_Xamarin:      @(NRMAPlatform_Xamarin),
             kNRMAPlatformString_Unity:        @(NRMAPlatform_Unity),
             kNRMAPlatformString_Appcelerator: @(NRMAPlatform_Appcelerator),
             kNRMAPlatformString_ReactNative:  @(NRMAPlatform_ReactNative),
             kNRMAPlatformString_Flutter:      @(NRMAPlatform_Flutter),
             kNRMAPlatformString_Capacitor:    @(NRMAPlatform_Capacitor),
             kNRMAPlatformString_MAUI:         @(NRMAPlatform_MAUI),
             kNRMAPlatformString_Unreal:       @(NRMAPlatform_Unreal)};
}

// Bundles a plugin's resources can land in: the main bundle, CocoaPods frameworks (use_frameworks!),
// and SwiftPM/CocoaPods resource bundles, which are nested in the app but not loaded until requested.
static NSArray<NSBundle*>* NRMACandidateResourceBundles(void) {
    NSMutableArray<NSBundle*>* bundles = [NSMutableArray arrayWithObject:[NSBundle mainBundle]];
    [bundles addObjectsFromArray:[NSBundle allBundles]];
    [bundles addObjectsFromArray:[NSBundle allFrameworks]];

    NSBundle* main = [NSBundle mainBundle];
    NSFileManager* fm = [NSFileManager defaultManager];
    for (NSURL* dir in [NSArray arrayWithObjects:main.bundleURL, main.privateFrameworksURL, nil]) {
        for (NSURL* item in [fm contentsOfDirectoryAtURL:dir includingPropertiesForKeys:nil options:0 error:nil]) {
            if ([item.pathExtension isEqualToString:@"bundle"] || [item.pathExtension isEqualToString:@"framework"]) {
                NSBundle* nested = [NSBundle bundleWithURL:item];
                if (nested) [bundles addObject:nested];
            }
        }
    }
    return bundles;
}

// Returns the contents of NewRelicHybrid.plist, or nil for a purely native app. Read once.
static NSDictionary* NRMAHybridPlist(void) {
    static NSDictionary* plist = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (NSBundle* bundle in NRMACandidateResourceBundles()) {
            NSURL* url = [bundle URLForResource:kNRMAHybridPlistName withExtension:@"plist"];
            NSDictionary* candidate = url ? [NSDictionary dictionaryWithContentsOfURL:url] : nil;
            if (candidate) {
                plist = candidate;
                return;
            }
        }
    });
    return plist;
}

// Default max event buffer time is 1 minute (60 seconds).
static NSUInteger __NRMA__maxEventBufferTime = 60;
static NSUInteger __NRMA__maxEventBufferSize = 1000;
static NSUInteger __NRMA__maxOfflineStorageSizeBytes = 100000000; // 100 MB in bytes

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
    __NRMA__applicationPlatformExplicit = YES;
}
+ (void) setPlatformVersion:(NSString*)platformVersion
{
    __NRMA__applicationPlatformVersion = platformVersion;
    __NRMA__applicationPlatformVersionExplicit = YES;
}

+ (NRMAApplicationPlatform) effectivePlatform {
    if (!__NRMA__applicationPlatformExplicit) {
        NSString* name = NRMAHybridPlist()[kNRMAHybridPlistFrameworkKey];
        NSNumber* platform = [name isKindOfClass:[NSString class]] ? NRMAPlatformsByName()[name] : nil;
        if (platform) {
            return (NRMAApplicationPlatform)platform.unsignedIntegerValue;
        }
    }
    return __NRMA__applicationPlatform;
}

+ (NSString*) effectivePlatformVersion {
    if (!__NRMA__applicationPlatformVersionExplicit) {
        NSString* version = NRMAHybridPlist()[kNRMAHybridPlistVersionKey];
        if ([version isKindOfClass:[NSString class]] && version.length) {
            return version;
        }
    }
    return __NRMA__applicationPlatformVersion;
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
    __NRMA__maxOfflineStorageSizeBytes = megabytes * 1000000; // Convert MB to bytes (1 MB = 1,000,000 bytes)
}

+ (NSUInteger) getMaxOfflineStorageSize {
    return __NRMA__maxOfflineStorageSizeBytes;
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
        
        if ([[NSProcessInfo processInfo] environment][@"UITesting"] ||
            [collectorHost isEqualToString:@"localhost:8080"]) {
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
    // For localhost capture mode, embed the http:// scheme so SessionReplayReporter
    // doesn't double-prepend https:// on top of a plain-HTTP host.
    BOOL isLocalhost = [_loggingURL isEqualToString:@"localhost:8080"];
    NSString* replayScheme = isLocalhost ? @"http://" : @"";
    _sessionReplayURL = [NSString stringWithFormat:@"%@%@/mobile/blobs", replayScheme, _loggingURL];

    _loggingURL = [_loggingURL stringByAppendingFormat:@"/mobile/logs"];
    // since setLoggingURL is always called we can make the session replay url here.

    NSString* logScheme = isLocalhost ? @"http://" : @"https://";
    NSString* logURL = [NSString stringWithFormat:@"%@%@", logScheme, _loggingURL];
    
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
    devInfo.platform = [NRMAAgentConfiguration effectivePlatform];
    devInfo.platformVersion = [NRMAAgentConfiguration effectivePlatformVersion];
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    connectionInformation.applicationInformation = appInfo;
    connectionInformation.deviceInformation = devInfo;
    
    return connectionInformation;
}

+ (BOOL)addLocalMaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        NSMutableArray *list = [NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers];
        @synchronized(list) {
            [list addObject:identifier];
        }
        NRLOG_AGENT_VERBOSE(@"Added masked accessibility identifier: %@", identifier);
        return true;
    }
    return false;
}

+ (BOOL)addLocalUnmaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        NSMutableArray *list = [NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers];
        @synchronized(list) {
            [list addObject:identifier];
        }
        NRLOG_AGENT_VERBOSE(@"Added unmasked accessibility identifier: %@", identifier);
        return true;
    }
    return false;
}

+ (BOOL)addLocalMaskedClassName:(NSString *)className {
    if (className.length > 0) {
        NSMutableArray *list = [NRMAAgentConfiguration local_session_replay_maskedClassNames];
        @synchronized(list) {
            [list addObject:className];
        }
        NRLOG_AGENT_VERBOSE(@"Added masked class name: %@", className);
        return true;
    }
    return false;
}

+ (BOOL)addLocalUnmaskedClassName:(NSString *)className {
    if (className.length > 0) {
        NSMutableArray *list = [NRMAAgentConfiguration local_session_replay_unmaskedClassNames];
        @synchronized(list) {
            [list addObject:className];
        }
        NRLOG_AGENT_VERBOSE(@"Added unmasked class name: %@", className);
        return true;
    }
    return false;
}


@end
