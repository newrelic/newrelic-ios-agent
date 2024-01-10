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

// Default max event buffer time is 10 minutes (600 seconds).
static NSUInteger __NRMA__maxEventBufferTime = 600;
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

+ (void) setMaxOfflineStorageSize:(NSUInteger)megaBytes {
    __NRMA__maxOfflineStorageSize = megaBytes;
}

+ (NSUInteger) getMaxOfflineStorageSize {
    return __NRMA__maxOfflineStorageSize;
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
    if (![NRMAFlags shouldEnableLogReporting]) { return; }

    if (self.applicationToken.regionCode.length) {
        _loggingURL = [NSString stringWithFormat:kNRMA_REGION_SPECIFIC_LOGGING_HOST,self.applicationToken.regionCode];
    }
    else if ([self.collectorHost isEqualToString:@"staging-mobile-collector.newrelic.com"]) {
        _loggingURL = kNRMA_STAGING_LOGGING_HOST;
    }
    else if ([NRMAFlags shouldEnableFedRampSupport]) {
        _loggingURL = kNRMA_FEDRAMP_LOGGING_HOST;
    }
    else {
        _loggingURL = kNRMA_DEFAULT_LOGGING_HOST;
    }
    _loggingURL = [_loggingURL stringByAppendingFormat:@"/log/v1"];

    NSString* logURL = [NSString stringWithFormat:@"%@%@", @"https://", _loggingURL];

    [NRLogger setLogURL:logURL];
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




@end
