//
//  NewRelicInternalUtils.h
//  NewRelicAgent
//
//  Created by Jonathan Karon on 9/21/12.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAReachability.h"
#import "NRConstants.h"
#import "NRMANetworkMonitor.h"
#import "BlockAttributeValidator.h"

#if __LP64__
#define NRMA_NSI "ld"
#define NRMA_NSU "lu"
#else
#define NRMA_NSI "d"
#define NRMA_NSU "u"
#endif

#define NRMA_OSNAME_IOS  @"iOS"
#define NRMA_OSNAME_TVOS @"tvOS"
#define NRMA_OSNAME_WATCHOS @"watchOS"

#define NRMA_HTTP_STATUS_CODE_ERROR_THRESHOLD 400

#define NRMASuppressPerformSelectorLeakWarning(expression) \
    do { \
        _Pragma("clang diagonstic pus") \
        _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
        expression; \
        _Pragma("clang diagnostic pop") \
} while (0)


static const NSString* kNRMACachedModelNumberKey = @"__nrma_model_number";

NSTimeInterval NRMAMillisecondTimestamp(void);

@interface NewRelicInternalUtils : NSObject

+ (BOOL) isInteger:(NSNumber*)number;
+ (BOOL) isFloat:(NSNumber*)number;
+ (BOOL) isBool:(NSNumber*)number;

// Returns YES if the current thread is believed to be a web view thread.
+ (BOOL) isWebViewThread;

// Returns the carrier name, or 'wifi' if the device is on a wifi network.
+ (NSString*) carrierName;

// Returns the connection type, wifi, ethernet, or cellular.
+ (NSString*) connectionType;

// Determines if a url is reachable.
+ (NRMANetworkStatus)currentReachabilityStatusTo:(NSURL*)url;

// Returns the url for the data endpoint.
+ (NSString*) collectorHostDataURL;

// Returns the url for the hex endpoint.
+ (NSString*) collectorHostHexURL;

// Returns the NRMANetworkStatus
+ (NRMANetworkStatus) networkStatus;

// Returns the current connection type. (Wifi, WAN, or precise radio technology)
+ (NSString*) getCurrentWanType;

// Returns the device model.  Ex.  iPhone4,1
+ (NSString *)deviceModel;

// Get the compiled in agent version number.
+ (NSString *)agentVersion;

// Get a unique device identifier for this install.
+ (NSString *)deviceId;

// Get the OS version for this device.
+ (NSString *)osName;

+ (NSString*) agentName;

+ (NSString *)osVersion;

+ (NSString *)deviceOrientation;

+ (NSString *)normalizedStringFromURL:(NSURL *)url;
+ (NSString *)normalizedStringFromString:(NSString *)url;

+ (NSString*) cleanseStringForCollector:(NSString*)string;

+ (BOOL) validateString:(NSString*)input usingRegularExpression:(NSRegularExpression*)regex;

+ (NSString*) stringFromNRMAApplicationPlatform:(NRMAApplicationPlatform) applicationPlatform;

+ (NSString*) getStorePath;

+ (BOOL)isDebuggerAttached;

+ (BOOL)isSimulator;

+ (NRMANetworkMonitor*) networkMonitor;

+ (NRMAReachability*) reachability;

+ (id<AttributeValidatorProtocol>) attributeValidator;

@end

