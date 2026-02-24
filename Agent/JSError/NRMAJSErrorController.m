//
//  NRMAJSErrorController.mm
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAJSErrorController.h"
#import "NRMAMobileErrorsUploader.h"
#import "NewRelicInternalUtils.h"
#import "NRLogger.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConfiguration.h"
#import "NRMAAppToken.h"
#import "NRMAFlags.h"
#import "NRMAAttributeValidator.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAMemoryVitals.h"
#import "NRMAReachability.h"

NSString* const kJSErrorBackupStoreFolder = @"jserrors/";

@interface NRMAJSErrorController ()

@property (nonatomic, strong) NSMutableArray<NSDictionary*>* errorQueue;
@property (nonatomic, strong) NSString* platform;
@property (nonatomic, strong) NRMAAgentConfiguration* agentConfiguration;
@property (nonatomic, strong) id<AttributeValidatorProtocol> attributeValidator;
@property (nonatomic, strong) NSLock* errorQueueLock;
@property (nonatomic, strong) NRMAMobileErrorsUploader* uploader;

@end

@implementation NRMAJSErrorController

// ARC handles dealloc automatically

- (instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics
                            sessionStartTime:(NSDate*)sessionStartDate
                          agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
                                    platform:(NSString*)platform
                                   sessionId:(NSString*)sessionId
                          attributeValidator:(id<AttributeValidatorProtocol>)attributeValidator {

    // Validate required parameters
    if (analytics == nil || sessionStartDate == nil || [agentConfiguration applicationToken] == nil ||
        platform == nil || sessionId == nil) {
        NSMutableArray* missingParams = [NSMutableArray new];
        if ([agentConfiguration applicationToken] == nil) [missingParams addObject:@"appToken"];
        if (platform == nil) [missingParams addObject:@"platformName"];
        if (sessionId == nil) [missingParams addObject:@"sessionId"];
        if (analytics == nil) [missingParams addObject:@"AnalyticsController"];
        if (sessionStartDate == nil) [missingParams addObject:@"SessionStartDate"];

        NRLOG_AGENT_ERROR(@"Failed to create JS error controller. Key parameter(s) are nil: %@. This will prevent JS error reporting.",
                         [missingParams componentsJoinedByString:@", "]);
        return nil;
    }

    self = [super init];
    if (self) {
        self.sessionId = sessionId;
        self.sessionStartDate = sessionStartDate;
        self.platform = platform;
        self.agentConfiguration = agentConfiguration;
        self.attributeValidator = attributeValidator;

        // Initialize error queue
        self.errorQueue = [NSMutableArray array];
        self.errorQueueLock = [[NSLock alloc] init];

        // Initialize uploader
        NSString* collectorHost = agentConfiguration.collectorHost ?: @"mobile-collector.newrelic.com";
        NSString* tokenString = [[agentConfiguration applicationToken] value];
        NSString* appVersion = [NRMAAgentConfiguration connectionInformation].applicationInformation.appVersion;
        self.uploader = [[NRMAMobileErrorsUploader alloc] initWithHost:collectorHost
                                                      applicationToken:tokenString
                                                            appVersion:appVersion
                                                                useSSL:agentConfiguration.useSSL];

        NRLOG_AGENT_VERBOSE(@"JS Error Controller initialized with collector: %@", collectorHost);
    }

    return self;
}

#pragma mark - Recording JS Errors

- (void) recordJSError:(NSString*)name
               message:(NSString*)message
            stackTrace:(NSString*)stackTrace
               isFatal:(BOOL)isFatal
          jsAppVersion:(NSString*)jsAppVersion
 additionalAttributes:(NSDictionary*)additionalAttributes {

    // Validate required parameters
    if (name == nil || name.length == 0) {
        NRLOG_AGENT_ERROR(@"Cannot record JS error: name is required");
        return;
    }

    if (message == nil || message.length == 0) {
        NRLOG_AGENT_ERROR(@"Cannot record JS error: message is required");
        return;
    }

    // Create error dictionary
    NSMutableDictionary* errorData = [NSMutableDictionary dictionary];

    // Add required fields
    errorData[@"name"] = name;
    errorData[@"message"] = message;
    errorData[@"stackTrace"] = stackTrace ?: @"";
    errorData[@"isFatal"] = @(isFatal);
    errorData[@"timestamp"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000));

    // Add optional fields
    if (jsAppVersion && jsAppVersion.length > 0) {
        errorData[@"jsAppVersion"] = jsAppVersion;
    }

    // Generate unique error ID
    errorData[@"errorId"] = [[NSUUID UUID] UUIDString];

    // Add additional attributes if provided
    if (additionalAttributes && [additionalAttributes count] > 0) {
        NSMutableDictionary* validatedAttributes = [NSMutableDictionary dictionary];

        for (NSString* key in additionalAttributes) {
            id value = additionalAttributes[key];

            // Validate attribute name and value
            if (self.attributeValidator) {
                if (![self.attributeValidator nameValidator:key]) {
                    NRLOG_AGENT_VERBOSE(@"Invalid attribute name: %@", key);
                    continue;
                }
                if (![self.attributeValidator valueValidator:value]) {
                    NRLOG_AGENT_VERBOSE(@"Invalid attribute value for key: %@", key);
                    continue;
                }
            }

            validatedAttributes[key] = value;
        }

        if ([validatedAttributes count] > 0) {
            errorData[@"additionalAttributes"] = validatedAttributes;
        }
    }

    // Add to queue (thread-safe)
    [self.errorQueueLock lock];
    [self.errorQueue addObject:errorData];
    NSUInteger queueSize = [self.errorQueue count];
    [self.errorQueueLock unlock];

    NRLOG_AGENT_VERBOSE(@"JS Error recorded: %@ - %@. Queue size: %lu", name, message, (unsigned long)queueSize);
}

#pragma mark - Harvest Cycle

- (void) onHarvestStart {
    NRLOG_AGENT_VERBOSE(@"JS Error harvest starting");
}

- (void) onHarvestBefore {
    // Prepare for harvest
}

- (void) onHarvest {
    NRLOG_AGENT_VERBOSE(@"JS Error harvest triggered");

    // First, process persisted errors from previous failed attempts
    if ([NRMAFlags shouldEnableOfflineStorage]) {
        [self processAndPublishPersistedErrors];
    }

    // Then get errors from in-memory queue (thread-safe)
    [self.errorQueueLock lock];
    NSArray<NSDictionary*>* errorsToSend = nil;
    if ([self.errorQueue count] > 0) {
        errorsToSend = [NSArray arrayWithArray:self.errorQueue];
        [self.errorQueue removeAllObjects];
    }
    [self.errorQueueLock unlock];

    if (errorsToSend && [errorsToSend count] > 0) {
        NRLOG_AGENT_INFO(@"Harvesting %lu JS errors", (unsigned long)[errorsToSend count]);
        [self publishErrors:errorsToSend];
    }

    // Retry failed uploads
    [self.uploader retryFailedUploads];
}

- (void) onHarvestComplete {
    NRLOG_AGENT_VERBOSE(@"JS Error harvest completed");
}

- (void) onHarvestError {
    NRLOG_AGENT_ERROR(@"JS Error harvest encountered an error");

    // Persist any remaining errors in queue for next harvest
    if ([NRMAFlags shouldEnableOfflineStorage]) {
        [self.errorQueueLock lock];
        NSArray<NSDictionary*>* errorsToPersist = [NSArray arrayWithArray:self.errorQueue];
        [self.errorQueue removeAllObjects];
        [self.errorQueueLock unlock];

        for (NSDictionary* errorData in errorsToPersist) {
            [self persistError:errorData];
        }

        if ([errorsToPersist count] > 0) {
            NRLOG_AGENT_VERBOSE(@"Persisted %lu JS errors due to harvest failure", (unsigned long)[errorsToPersist count]);
        }
    }
}

- (void) onHarvestStop {
    NRLOG_AGENT_VERBOSE(@"JS Error harvest stopped");
}

- (void) onHarvestConnected {
    // Connection established
}

- (void) onHarvestDisconnected {
    // Connection lost
}

#pragma mark - Publishing

- (void) publishErrors:(NSArray<NSDictionary*>*)errors {
    if (!errors || [errors count] == 0) {
        return;
    }

    // Format payload according to Mobile Errors Protocol
    NSDictionary* payload = [self formatPayload:errors];

    // Log payload for debugging
    NSError* jsonError = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
    if (jsonData && !jsonError) {
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"========== Mobile Errors Payload ==========");
        NSLog(@"Publishing %lu JS errors", (unsigned long)[errors count]);
        NSLog(@"Payload:\n%@", jsonString);
        NSLog(@"===========================================");
        NRLOG_AGENT_VERBOSE(@"Publishing %lu JS errors. Payload: %@", (unsigned long)[errors count], jsonString);
    }

    // Get session ID, entity GUID, account IDs, and tokens for headers
    NSString* sessionId = self.sessionId;
    NSString* entityGuid = nil;
    NSNumber* accountId = nil;
    NSNumber* trustedAccountId = nil;
    NSString* sessionToken = nil;
    NSString* agentConfigToken = nil;

    NRMAHarvesterConfiguration* configuration = [NRMAHarvestController configuration];
    if (configuration.entity_guid && configuration.entity_guid.length > 0) {
        entityGuid = configuration.entity_guid;
    }
    if (configuration.account_id > 0) {
        accountId = @(configuration.account_id);
    }
    if (configuration.trusted_account_key && configuration.trusted_account_key.length > 0) {
        trustedAccountId = @([configuration.trusted_account_key longLongValue]);
    }

    // Extract tokens from request_header_map (from connect response)
    if (configuration.request_header_map) {
        sessionToken = configuration.request_header_map[@"NR-Session"];
        agentConfigToken = configuration.request_header_map[@"NR-AgentConfiguration"];
    }

    // Send to /mobile/errors endpoint
    [self.uploader sendPayload:payload
                     sessionId:sessionId
                    entityGuid:entityGuid
                     accountId:accountId
              trustedAccountId:trustedAccountId
                  sessionToken:sessionToken
             agentConfigToken:agentConfigToken];
}

- (NSDictionary*) formatPayload:(NSArray<NSDictionary*>*)errors {
    NSMutableDictionary* payload = [NSMutableDictionary dictionary];
    NRMAConnectInformation* connectInfo = [NRMAAgentConfiguration connectionInformation];
    NRMAHarvesterConfiguration* configuration = [NRMAHarvestController configuration];

    // Match ANR protocol structure
    payload[@"timestamp"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000));

    // Agent info
    payload[@"agentName"] = [NewRelicInternalUtils agentName];

    // Use platformVersion if set, otherwise fall back to agentVersion (same as logs)
    NSString* version = connectInfo.deviceInformation.platformVersion ?: connectInfo.deviceInformation.agentVersion;
    payload[@"agentVersion"] = version ?: [NewRelicInternalUtils agentVersion];

    // Data token [appId, appVersionId]
    if (configuration.application_id > 0) {
        payload[@"dataToken"] = @[@(configuration.application_id), @0];
    }

    // Build ID
    if (connectInfo.applicationInformation.appBuild) {
        payload[@"buildId"] = connectInfo.applicationInformation.appBuild;
    }

    // Device info
    payload[@"deviceInfo"] = [self getDeviceInfo];

    // Session attributes (simplified per ReactNative example)
    NSMutableDictionary* sessionAttributes = [NSMutableDictionary dictionary];

    // Session ID (required)
    if (self.sessionId) {
        sessionAttributes[@"sessionId"] = self.sessionId;
    }

    // Other session attributes can be added here (custom key-value pairs)
    // The backend will add device/session info from headers and deviceInfo

    payload[@"sessionAttributes"] = sessionAttributes;

    // App info
    NSMutableDictionary* appInfo = [NSMutableDictionary dictionary];
    if (connectInfo.applicationInformation.appName) {
        appInfo[@"appName"] = connectInfo.applicationInformation.appName;
    }
    if (connectInfo.applicationInformation.appVersion) {
        appInfo[@"appVersion"] = connectInfo.applicationInformation.appVersion;
    }
    if (connectInfo.applicationInformation.bundleId) {
        appInfo[@"bundleId"] = connectInfo.applicationInformation.bundleId;
    }
    if (connectInfo.applicationInformation.appBuild) {
        appInfo[@"appBuild"] = connectInfo.applicationInformation.appBuild;
    }
    payload[@"appInfo"] = appInfo;

    // Format analytics events
    NSMutableArray* analyticsEvents = [NSMutableArray array];
    for (NSDictionary* errorData in errors) {
        NSDictionary* event = [self formatErrorAsEvent:errorData];
        [analyticsEvents addObject:event];
    }
    payload[@"analyticsEvents"] = analyticsEvents;

    return payload;
}

- (NSDictionary*) formatErrorAsEvent:(NSDictionary*)errorData {
    NSMutableDictionary* event = [NSMutableDictionary dictionary];

    // Match Mobile Errors Protocol for ReactNative (Default Mode)
    event[@"eventType"] = @"MobileJSError";
    event[@"timestamp"] = errorData[@"timestamp"];

    // Required fields per protocol
    event[@"errorId"] = errorData[@"errorId"];
    event[@"description"] = errorData[@"message"];
    event[@"errorType"] = errorData[@"name"];

    // isFatal as string boolean
    BOOL isFatal = [errorData[@"isFatal"] boolValue];
    event[@"isFatalError"] = isFatal ? @"true" : @"false";

    // URL-encode stack trace for threads field
    NSString* stackTrace = errorData[@"stackTrace"];
    if (stackTrace && stackTrace.length > 0) {
        event[@"threads"] = [self urlEncodeStackTrace:stackTrace];
    }

    // Cause (optional customer message)
    event[@"cause"] = @"React Native JavaScript error";

    // Add additional attributes to event
    if (errorData[@"additionalAttributes"]) {
        NSDictionary* additionalAttrs = errorData[@"additionalAttributes"];
        for (NSString* key in additionalAttrs) {
            // Don't overwrite reserved fields
            if (![event objectForKey:key]) {
                event[key] = additionalAttrs[key];
            }
        }
    }

    return event;
}

- (NSString*) urlEncodeStackTrace:(NSString*)stackTrace {
    // URL encode the stack trace as required by Mobile Errors Protocol
    NSCharacterSet* allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString* encoded = [stackTrace stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    return encoded ?: stackTrace;
}

- (NSDictionary*) getDeviceInfo {
    NSMutableDictionary* deviceInfo = [NSMutableDictionary dictionary];

    // Memory Usage
    double memoryUsageMB = [NRMAMemoryVitals memoryUseInMegabytes];
    deviceInfo[@"memoryUsage"] = @((NSInteger)memoryUsageMB);

    // Device Orientation
    NSInteger orientationValue = 0;
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsLandscape(deviceOrientation)) {
        orientationValue = 2;
    } else if (UIDeviceOrientationIsPortrait(deviceOrientation)) {
        orientationValue = 1;
    }
    deviceInfo[@"orientation"] = @(orientationValue);

    // Network Status
    NRMANetworkStatus networkStatus = [NewRelicInternalUtils networkStatus];
    NSString* networkStatusString = @"wifi";
    if (networkStatus == ReachableViaWWAN) {
        networkStatusString = @"cellular";
    } else if (networkStatus == NotReachable) {
        networkStatusString = @"none";
    }
    deviceInfo[@"networkStatus"] = networkStatusString;

    // Disk Available (iOS - available space)
    NSError* error = nil;
    NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (fileAttributes && !error) {
        unsigned long long freeSpace = [[fileAttributes objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
        deviceInfo[@"diskAvailable"] = @[@(freeSpace / (1024 * 1024))]; // Convert to MB
    }

    // OS Version
    deviceInfo[@"osVersion"] = [[UIDevice currentDevice] systemVersion];

    // Device Name
    deviceInfo[@"deviceName"] = [[UIDevice currentDevice] name];

    // OS Build (if available)
    deviceInfo[@"osBuild"] = [NewRelicInternalUtils osVersion] ?: @"";

    // Model Number
    deviceInfo[@"modelNumber"] = [NewRelicInternalUtils deviceModel];

    // Device UUID
    deviceInfo[@"deviceUuid"] = [NewRelicInternalUtils deviceId];

    // Runtime version (Swift/Objective-C runtime)
    deviceInfo[@"runTime"] = [NewRelicInternalUtils agentVersion];

    return deviceInfo;
}

#pragma mark - Persistence

- (void) persistError:(NSDictionary*)errorData {
    // Get storage path
    NSString* storePath = [NewRelicInternalUtils getStorePath];
    NSString* jsErrorPath = [storePath stringByAppendingPathComponent:kJSErrorBackupStoreFolder];

    // Create directory if it doesn't exist
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:jsErrorPath]) {
        NSError* error = nil;
        [fileManager createDirectoryAtPath:jsErrorPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            NRLOG_AGENT_ERROR(@"Failed to create JS error backup directory: %@", error);
            return;
        }
    }

    // Create filename with error ID
    NSString* errorId = errorData[@"errorId"];
    NSString* filename = [NSString stringWithFormat:@"%@.json", errorId];
    NSString* filePath = [jsErrorPath stringByAppendingPathComponent:filename];

    // Serialize to JSON
    NSError* error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:errorData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to serialize JS error to JSON: %@", error);
        return;
    }

    // Write to disk
    [jsonData writeToFile:filePath atomically:YES];
    NRLOG_AGENT_VERBOSE(@"Persisted JS error to: %@", filePath);
}

- (void) processAndPublishPersistedErrors {
    NSString* storePath = [NewRelicInternalUtils getStorePath];
    NSString* jsErrorPath = [storePath stringByAppendingPathComponent:kJSErrorBackupStoreFolder];

    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:jsErrorPath]) {
        return;
    }

    // Get all JSON files
    NSError* error = nil;
    NSArray* files = [fileManager contentsOfDirectoryAtPath:jsErrorPath error:&error];
    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to read JS error backup directory: %@", error);
        return;
    }

    NSMutableArray* persistedErrors = [NSMutableArray array];

    for (NSString* filename in files) {
        if (![filename hasSuffix:@".json"]) {
            continue;
        }

        NSString* filePath = [jsErrorPath stringByAppendingPathComponent:filename];

        // Read file
        NSData* jsonData = [NSData dataWithContentsOfFile:filePath];
        if (!jsonData) {
            continue;
        }

        // Deserialize JSON
        NSError* jsonError = nil;
        NSDictionary* errorData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                  options:0
                                                                    error:&jsonError];
        if (jsonError) {
            NRLOG_AGENT_ERROR(@"Failed to deserialize persisted JS error: %@", jsonError);
            // Delete corrupted file
            [fileManager removeItemAtPath:filePath error:nil];
            continue;
        }

        [persistedErrors addObject:errorData];

        // Delete file after reading
        [fileManager removeItemAtPath:filePath error:nil];
    }

    if ([persistedErrors count] > 0) {
        NRLOG_AGENT_INFO(@"Publishing %lu persisted JS errors", (unsigned long)[persistedErrors count]);
        [self publishErrors:persistedErrors];
    }
}

@end
