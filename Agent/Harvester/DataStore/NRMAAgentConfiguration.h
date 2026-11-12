//
//  NRMAAgentConfiguration.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAConnectInformation.h"
#import <Foundation/Foundation.h>

@class NRMAAppToken;
@class NRMAPlatformDetection;

// Collector Hosts.
#define kNRMA_DEFAULT_COLLECTOR_HOST         @"mobile-collector.newrelic.com"
#define kNRMA_DEFAULT_CRASH_COLLECTOR_HOST   @"mobile-crash.newrelic.com"
#define kNRMA_FEDRAMP_COLLECTOR_HOST         @"gov-mobile-collector.newrelic.com"
#define KNRMA_FEDRAMP_CRASH_COLLECTOR_HOST   @"gov-mobile-crash.newrelic.com"
#define kNRMA_REGION_SPECIFIC_COLLECTOR_HOST @"mobile-collector.%@.nr-data.net"
#define kNRMA_REGION_SPECIFIC_CRASH_HOST     @"mobile-crash.%@.nr-data.net"

// Logging Hosts.
#define kNRMA_DEFAULT_LOGGING_HOST           @"mobile-collector.newrelic.com"
#define kNRMA_REGION_SPECIFIC_LOGGING_HOST   @"mobile-collector.%@.nr-data.net"
#define kNRMA_STAGING_LOGGING_HOST           @"staging-mobile-collector.newrelic.com"
#define kNRMA_FEDRAMP_LOGGING_HOST           @"gov-mobile-collector.newrelic.com"
#define kNRMA_STAGING_FEDRAMP_LOGGING_HOST   @"gov-staging-mobile-collector.newrelic"

@interface NRMAAgentConfiguration : NSObject

@property(readonly,strong) NSString* collectorHost;
@property(readonly,strong) NSString* crashCollectorHost;
@property(readonly,strong) NSString* loggingHost;
@property(readonly,strong) NSString* loggingURL;
@property(readonly,strong) NSString* sessionReplayURL;
@property(readonly,strong) NSString* sessionReplayMode;

@property(readonly,strong) NRMAAppToken* applicationToken;
@property(atomic,strong) NSString* sessionIdentifier;
@property(nonatomic,readonly) BOOL      useSSL;
@property(atomic,assign) NRMAApplicationPlatform platform;

- (id) initWithAppToken:(NRMAAppToken*)token collectorAddress:(NSString*)collectorAddress crashAddress:(NSString*)crashAddress;

+ (NRMAConnectInformation*) connectionInformation;
+ (void)setApplicationVersion:(NSString *)versionString;
+ (void)setApplicationBuild:(NSString *)buildString;
+ (void) setPlatform:(NRMAApplicationPlatform)platform;
+ (void) setPlatformVersion:(NSString*)platformVersion;

// YES once +setPlatform: was called, even with NRMAPlatform_Native. A detected platform does not count.
+ (BOOL) isPlatformExplicit;
// Decides the platform before anything captures it. Precedence: an explicit +setPlatform:, then what
// NRMAPlatformDetector finds, then Native. A detected version is used only when +setPlatformVersion: was not called.
+ (void) resolvePlatform;
+ (void) resolvePlatformWithDetector:(NRMAPlatformDetection* (^)(void))detect;
// Testing only: back to the defaults, with nothing set explicitly.
+ (void) resetPlatformForTesting;

+ (void) setMaxEventBufferTime:(NSUInteger)seconds;
+ (NSUInteger) getMaxEventBufferTime;

+ (void) setMaxEventBufferSize:(NSUInteger)size;
+ (NSUInteger) getMaxEventBufferSize;

+ (void) setMaxOfflineStorageSize:(NSUInteger)megabytes;
+ (NSUInteger) getMaxOfflineStorageSize;

+ (NSMutableArray*) local_session_replay_maskedClassNames;
+ (NSMutableArray*) local_session_replay_unmaskedClassNames;
+ (NSMutableArray*) local_session_replay_maskedAccessibilityIdentifiers;
+ (NSMutableArray*) local_session_replay_unmaskedAccessibilityIdentifiers;

+ (BOOL)addLocalMaskedAccessibilityIdentifier:(NSString *)identifier;
+ (BOOL)addLocalUnmaskedAccessibilityIdentifier:(NSString *)identifier;
+ (BOOL)addLocalMaskedClassName:(NSString *)className;
+ (BOOL)addLocalUnmaskedClassName:(NSString *)className;
@end
