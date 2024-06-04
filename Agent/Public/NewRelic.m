//
//  NewRelic.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 11/4/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATraceController.h"
#import "NRConstants.h"
#import "NRMACustomTrace.h"
#import "NRCustomMetrics.h"
#import <objc/runtime.h>
#import "NRMAMeasurements.h"
#import "NewRelicAgentInternal.h"
#import "NRMAFlags.h"
#import "NewRelicInternalUtils.h"
#import "NRMAExceptionHandler.h"
#import "NRMATaskQueue.h"
#import "NRMAHTTPTransaction.h"
#import "NRMATraceMachineAgentUserInterface.h"
#import "NRMAThreadInfo.h"
#import "NRMAAnalytics.h"
#import "NRMAKeyAttributes.h"
#import "NRMANetworkFacade.h"
#import "NewRelic.h"
#import "NRMAHarvestController.h"
#import "NRMAURLTransformer.h"
#import "NRMAHTTPUtilities.h"
#import "Constants.h"

#define kNRMA_NAME @"name"

@implementation NewRelic

+ (void) crashNow
{
    [self crashNow:nil];
}

+ (void) logInfo:(NSString* __nonnull) message {
    NRLOG_INFO(@"%@", message);
}

+ (void) logError:(NSString* __nonnull) message {
    NRLOG_ERROR(@"%@", message);
}

+ (void) logVerbose:(NSString* __nonnull) message {
    NRLOG_VERBOSE(@"%@", message);
}
+ (void) logWarning:(NSString* __nonnull) message {
    NRLOG_WARNING(@"%@", message);
}

+ (void) logAudit:(NSString* __nonnull) message {
    NRLOG_AUDIT(@"%@", message);
}

+ (void) logDebug:(NSString* __nonnull) message {
    NRLOG_DEBUG(@"%@", message);
}

+ (void) log:(NSString* __nonnull) message level:(NRLogLevels)level {
    switch (level) {
        case NRLogLevelError:
            NRLOG_ERROR(@"%@", message);
            break;
        case NRLogLevelWarning:
            NRLOG_WARNING(@"%@", message);
            break;
        case NRLogLevelInfo:
            NRLOG_INFO(@"%@", message);
            break;
        case NRLogLevelVerbose:
            NRLOG_VERBOSE(@"%@", message);
            break;
        case NRLogLevelAudit:
            NRLOG_AUDIT(@"%@", message);
            break;
        case NRLogLevelDebug:
            NRLOG_DEBUG(@"%@", message);
            break;
        default:
            break;
    }
}

+ (void) logAll:(NSDictionary* __nonnull) dict {
    NSString* message = [dict objectForKey:@"message"];
    NSString* level = [dict objectForKey:@"logLevel"];

    NRLogLevels levels = [NRLogger stringToLevel: level];

    [self log:message level:levels];
}

+ (void) logAttributes:(NSDictionary* __nonnull) dict {
    NSString* message = [dict objectForKey:@"message"];
    NSString* level = [dict objectForKey:@"logLevel"];

    NRLogLevels levels = [NRLogger stringToLevel: level];

    [self log:message level:levels];
}

+ (void) logErrorObject:(NSError* __nonnull) error {
    NSString * errorDesc = error.localizedDescription;

    [self logError:[NSString stringWithFormat:@"Error encountered: %@", errorDesc]];
}

+ (void) crashNow:(NSString*)message
{
    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    @throw [NSException exceptionWithName:@"NewRelicDemoException"
                                   reason:message?:@"This is a demo crash from +[NewRelic demoCrash:]"
                                 userInfo:nil];
}

+ (void)setApplicationVersion:(NSString *)versionString
{
    if ([NewRelicAgentInternal sharedInstance] != nil) {
        @throw [NSException exceptionWithName:@"InvalidUsageException" reason:[NSString stringWithFormat:@"'%@' may only be called prior to calling +[NewRelic startWithApplicationToken:]",NSStringFromSelector(_cmd)] userInfo:nil];
    }
    [NRMAAgentConfiguration setApplicationVersion:versionString];
}

+ (void) setApplicationBuild:(NSString *)buildNumber {
    if ([NewRelicAgentInternal sharedInstance] != nil) {
        @throw [NSException exceptionWithName:@"InvalidUsageException" reason:[NSString stringWithFormat:@"'%@' may only be called prior to calling +[NewRelic startWithApplicationToken:]",NSStringFromSelector(_cmd)] userInfo:nil];
    }
    [NRMAAgentConfiguration setApplicationBuild:buildNumber];
}

+ (void) recordHandledException:(NSException*)exception {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    [[NewRelicAgentInternal sharedInstance].handledExceptionsController recordHandledException:exception];
}

+ (void) recordHandledException:(NSException*)exception
           withAttributes:(NSDictionary*)attributes {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }
    [[NewRelicAgentInternal sharedInstance].handledExceptionsController recordHandledException:exception
                                                                                    attributes:attributes];
}

+ (void)recordHandledExceptionWithStackTrace:(NSDictionary* _Nonnull)exceptionDictionary {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    [[NewRelicAgentInternal sharedInstance].handledExceptionsController recordHandledExceptionWithStackTrace:exceptionDictionary];

}

+ (void) recordError:(NSError* _Nonnull)error {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    [[NewRelicAgentInternal sharedInstance].handledExceptionsController recordError:error
                                                                         attributes:nil];
}

+ (void) recordError:(NSError* _Nonnull)error
          attributes:(NSDictionary* _Nullable)attributes
{
    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    [[NewRelicAgentInternal sharedInstance].handledExceptionsController recordError:error
                                                                         attributes:attributes];
}

+ (void) setPlatform:(NRMAApplicationPlatform)platform {
    [NRMAAgentConfiguration setPlatform:platform];
}

//hidden API
+ (void) setPlatformVersion:(NSString*)platformVersion {
    [NRMAAgentConfiguration setPlatformVersion:platformVersion];
}

+ (void) saltDeviceUUID:(BOOL)enabled {
    [NRMAFlags setSaltDeviceUUID:enabled];
}

// Hidden API for Private Setting Replace Device Identifier

/// replaceDeviceIdentifier allows device identifier to be replaced with a string `identifier`
/// NOTE: Whitespace and new lines will be trimmed.
/// If the trimmed device identifier replacement is blank then "0" will be used.
/// @param identifier  pass replacement String. pass NULL to stop replacing.
+ (void) replaceDeviceIdentifier:(NSString*)identifier {
    [NRMAFlags setShouldReplaceDeviceIdentifier:identifier];
}

+ (NSString*) currentSessionId {
    return [[[NewRelicAgentInternal sharedInstance] currentSessionId] copy];
}

+ (NSString*) crossProcessId {
    return [[[[NRMAHarvestController harvestController] harvester] crossProcessID] copy];
}

#pragma mark - manage feature flags
+ (void) enableFeatures:(NRMAFeatureFlags)featureFlags
{
    [NRMAFlags enableFeatures:featureFlags];
}

+ (void) disableFeatures:(NRMAFeatureFlags)featureFlags
{
    [NRMAFlags disableFeatures:featureFlags];
}

+ (void) enableCrashReporting:(BOOL)enabled
{
    if (enabled) {
        [NRMAFlags enableFeatures:NRFeatureFlag_CrashReporting];
    } else {
        [NRMAFlags disableFeatures:NRFeatureFlag_CrashReporting];
    }
}

#pragma mark - Stopping the agent

+ (void)shutdown {
    [NewRelicAgentInternal shutdown];
}

#pragma mark - Starting up the agent

+ (void)startWithApplicationToken:(NSString*)appToken
{
    [NewRelicAgentInternal startWithApplicationToken:appToken
            andCollectorAddress:nil];
}


+ (void)startWithApplicationToken:(NSString*)appToken
                  withoutSecurity:(BOOL)disableSSL {

    [NewRelicAgentInternal startWithApplicationToken:appToken
                                 andCollectorAddress:nil];
}

+ (void)startWithApplicationToken:(NSString*)appToken andCollectorAddress:(NSString*)url
{
    [NewRelicAgentInternal startWithApplicationToken:appToken
                                 andCollectorAddress:url];
}

+ (void)startWithApplicationToken:(NSString*)appToken
              andCollectorAddress:(NSString*)url
         andCrashCollectorAddress:(NSString *)crashCollectorUrl
{
    [NewRelicAgentInternal startWithApplicationToken:appToken
                                 andCollectorAddress:url
                            andCrashCollectorAddress:crashCollectorUrl];
}
#pragma mark - NRMATimer helper

+ (NRTimer *)createAndStartTimer
{
    return [[NRTimer alloc] init];
}



#pragma mark - noticeNetwork helpers


+ (void)noticeNetworkRequestForURL:(NSURL *)url
                        httpMethod:(NSString *)httpMethod
                         withTimer:(NRTimer *)timer
                   responseHeaders:(NSDictionary *)headers
                        statusCode:(NSInteger)httpStatusCode
                         bytesSent:(NSUInteger)bytesSent
                     bytesReceived:(NSUInteger)bytesReceived
                      responseData:(NSData *)responseData
                      traceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders
                         andParams:(NSDictionary *)params {

    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSHTTPURLResponse*  response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                               statusCode:httpStatusCode
                                                              HTTPVersion:@"1.1"
                                                             headerFields:headers];
    [request setHTTPMethod:httpMethod];
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:timer
                                  bytesSent:bytesSent
                              bytesReceived:bytesReceived
                               responseData:responseData
                               traceHeaders:traceHeaders
                                     params:params];
}

+ (void)noticeNetworkRequestForURL:(NSURL *)url
                        httpMethod:(NSString *)httpMethod
                         startTime:(double)startTime
                         endTime:(double)endTime
                   responseHeaders:(NSDictionary *)headers
                        statusCode:(NSInteger)httpStatusCode
                         bytesSent:(NSUInteger)bytesSent
                     bytesReceived:(NSUInteger)bytesReceived
                      responseData:(NSData *)responseData
                      traceHeaders:(NSDictionary*)traceHeaders
                         andParams:(NSDictionary *)params {

    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSHTTPURLResponse*  response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                               statusCode:httpStatusCode
                                                              HTTPVersion:@"1.1"
                                                             headerFields:headers];
    [request setHTTPMethod:httpMethod];
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  bytesSent:bytesSent
                              bytesReceived:bytesReceived
                               responseData:responseData
                               traceHeaders:traceHeaders
                                     params:params];
}

+ (void)noticeNetworkFailureForURL:(NSURL *)url
                        httpMethod:(NSString*)httpMethod
                         withTimer:(NRTimer *)timer
                    andFailureCode:(NSInteger)iOSFailureCode {
    NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:iOSFailureCode
                                     userInfo:nil];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:httpMethod];

    [NRMANetworkFacade noticeNetworkFailure:request
                                  withTimer:timer
                                  withError:error];
}

+ (void)noticeNetworkFailureForURL:(NSURL *)url
                        httpMethod:(NSString*)httpMethod
                         startTime:(double)startTime
                           endTime:(double)endTime
                    andFailureCode:(NSInteger)iOSFailureCode {
    NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:iOSFailureCode
                                     userInfo:nil];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:httpMethod];

    [NRMANetworkFacade noticeNetworkFailure:request
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  withError:error];
}

+ (NSDictionary<NSString*,NSString*>*)generateDistributedTracingHeaders {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [NRMAHTTPUtilities generateConnectivityHeadersWithNRMAPayload:[NRMAHTTPUtilities generateNRMAPayload]];
    } else {
        return [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:[NRMAHTTPUtilities generatePayload]];
    }
}

+  (void)addHTTPHeaderTrackingFor:(NSArray<NSString*> *_Nonnull)headers {
    [NRMAHTTPUtilities addHTTPHeaderTrackingFor:headers];
}

+ (NSArray<NSString*>* _Nonnull)httpHeadersAddedForTracking {
    return [NRMAHTTPUtilities trackedHeaderFields];
}


#pragma mark - Interactions

+ (NSString*) startInteractionWithName:(NSString*)interactionName
{

    // If Agent is shutdown we shouldn't record traces.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return nil;
    }

    if (![NRMAFlags shouldEnableInteractionTracing]){
        NRLOG_VERBOSE(@"\"%@\" not executing; Interaction tracing is disabled.",NSStringFromSelector(_cmd));
        return nil;
    }

#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif

        return [NRMATraceMachineAgentUserInterface startCustomActivity:interactionName];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    }  @catch (NSException *exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:NSStringFromSelector(_cmd)];
        [NRMATraceController cleanup];
        return nil;
    }

#endif
}


+ (void) stopCurrentInteraction:(NSString*)activityIdentifier
{
    // If Agent is shutdown we shouldn't record traces.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    if (![NRMAFlags shouldEnableInteractionTracing]){
        NRLOG_VERBOSE(@"\"%@\" not executing; Interaction tracing is disabled.",NSStringFromSelector(_cmd));
        return;
    }
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        [NRMATraceMachineAgentUserInterface stopCustomActivity:activityIdentifier];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    }  @catch (NSException *exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:NSStringFromSelector(_cmd)];
        [NRMATraceController cleanup];
    }
#endif
}


#pragma mark - Method Tracing

+ (void) startTracingMethod:(SEL)selector
                     object:(id)object
                      timer:(NRTimer *)timer
                   category:(enum NRTraceType)category
{
   [self startTracingMethodNamed:NSStringFromSelector(selector)
                     objectNamed:NSStringFromClass([object class])
                           timer:timer
                        category:category];
}

+ (void) startTracingMethodNamed:(NSString*)methodName
                     objectNamed:(NSString*)objectName
                      timer:(NRTimer *)timer
                   category:(enum NRTraceType)category{

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    if (![NRMAFlags shouldEnableInteractionTracing]){
        NRLOG_VERBOSE(@"\"%@\" not executing; Interaction tracing is disabled.",NSStringFromSelector(_cmd));
        return;
    }

    NSString* cleanSelectorString = [NewRelicInternalUtils cleanseStringForCollector:methodName];

    if (![NRMATraceController isTracingActive]) {
        NRLOG_VERBOSE(@"%@ attempted to start tracing method without active Interaction Trace",NSStringFromSelector(_cmd));
        return;
    }
    [NRMACustomTrace startTracingMethod:NSSelectorFromString(cleanSelectorString)
                             objectName:objectName
                                  timer:timer
                               category:category];


}


+ (void) endTracingMethodWithTimer:(NRTimer *)timer
{
    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }

    [timer stopTimer];
    if (![NRMAFlags shouldEnableInteractionTracing]){
        NRLOG_VERBOSE(@"\"%@\" not executing; Interaction tracing is disabled.",NSStringFromSelector(_cmd));
        //need to remove the associated object or else this will leak!
        return;
    }
    if (![NRMATraceController isTracingActive]) {
        NRLOG_VERBOSE(@"%@ attempted to end tracing method without active Interaction Trace",NSStringFromSelector(_cmd));
        //need to remove the associated object or else this will leak!
        if (timer) {
            objc_setAssociatedObject(timer, (__bridge const void *)(kNRTraceAssociatedKey), Nil, OBJC_ASSOCIATION_ASSIGN);
        }
        return;
    }
    [NRMACustomTrace endTracingMethodWithTimer:timer];
}

#pragma mark - Custom Metrics


+ (void) recordMetricWithName:(NSString *)name
                     category:(NSString *)category
{
    [NRCustomMetrics recordMetricWithName:name category:category];
}

+ (void) recordMetricWithName:(NSString *)name
                     category:(NSString *)category
                        value:(NSNumber *)value
{
    [NRCustomMetrics recordMetricWithName:name
                                 category:category
                                    value:value];
}

+ (void) recordMetricWithName:(NSString *)name
                     category:(NSString *)category
                        value:(NSNumber *)value
                   valueUnits:(NSString *)valueUnits
{
    [NRCustomMetrics recordMetricWithName:name
                                 category:category
                                    value:value
                               valueUnits:valueUnits];
}

+ (void) recordMetricWithName:(NSString *)name
                     category:(NSString *)category
                        value:(NSNumber *)value
                   valueUnits:(NSString *)valueUnits
                   countUnits:(NSString *)countUnits
{
    [NRCustomMetrics recordMetricWithName:name
                                 category:category
                                    value:value
                               valueUnits:valueUnits
                               countUnits:countUnits];
}

+ (BOOL) harvestNow
{
    return [NewRelicAgentInternal harvestNow];
}


#pragma mark - Custom attributes

+ (BOOL) setAttribute:(NSString*)name
                value:(id) value {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController setSessionAttribute:name
                                                                                     value:value
                                                                                    persistent:YES];
}

+ (BOOL) incrementAttribute:(NSString*)name {
    return [NewRelic incrementAttribute:name value:@1];
}

+ (BOOL) incrementAttribute:(NSString*)name
                      value:(NSNumber*) value {
    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController incrementSessionAttribute:name
                                                                                           value:value
                                                                                      persistent:YES];
}

+ (BOOL) setUserId:(NSString* _Nullable)userId {

    /*
     
     1. When setUserID(value: string|null) is called:
        a. If userID was previously null and new value is non-null:
            i. continue the current session and set the new userID
        b. If userID was previously not-null and new value is different (including null):
            i. end the current session and perform harvest
            ii. start a new session with the new userID
     */
    NSString *previousUserId = [[NewRelicAgentInternal sharedInstance] getUserId];
    BOOL newSession = false;
    // If the client passes a new userId that is non NULL.
    if (userId != NULL) {
        // If userId has not previously been set.
        if (previousUserId == NULL) {
            // continue session and set the new userID
        }
        // A new userId has been set where the previous one was not NULL.
        else {
            newSession = true;
        }
    }
    // If the client passes a new NULL userId.
    else {
        if (previousUserId == NULL) {
            // Do nothing if passed user id is null and saved userId is null.
        }
        else {
            // end session and harvest.
            newSession = true;
        }
    }
    
    BOOL success = [[NewRelicAgentInternal sharedInstance].analyticsController setSessionAttribute:kNRMA_Attrib_userId
                                                                                             value:userId
                                                                                        persistent:YES];

    // If passed userId == NULL , remove UserId attribute.
    if (userId == NULL) {
        success = [[NewRelicAgentInternal sharedInstance].analyticsController removeSessionAttributeNamed:kNRMA_Attrib_userId];
    }

    [NewRelicAgentInternal sharedInstance].userId = userId;

    if (newSession) {
        [[[NewRelicAgentInternal sharedInstance] analyticsController] newSession];

        [self harvestNow];

        // Update in memory userId.

        [[NewRelicAgentInternal sharedInstance] sessionStartInitialization];
    }

    return success;

}

+ (BOOL) removeAttribute:(NSString*)name {
    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController removeSessionAttributeNamed:name];
}

+ (BOOL) removeAllAttributes {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController removeAllSessionAttributes];
}

#pragma mark - Custom events


+ (BOOL) recordCustomEvent:(NSString*)eventType
                      name:(NSString*)name
                attributes:(NSDictionary*)attributes {

    NSMutableDictionary* mutableAttributes = attributes?[attributes mutableCopy]:[NSMutableDictionary new];
    if(name.length) {
        [mutableAttributes setValue:name forKey:kNRMA_NAME];
    }
    return [NewRelic recordCustomEvent:eventType attributes:mutableAttributes];
}

+ (BOOL) recordCustomEvent:(NSString*)eventType
                attributes:(NSDictionary*)attributes {

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController addCustomEvent:eventType
                                                                       withAttributes:attributes];
}


+ (BOOL) recordBreadcrumb:(NSString* __nonnull)name
               attributes:(NSDictionary* __nullable)attributes
{

    // If Agent is shutdown we shouldn't respond.
    if([NewRelicAgentInternal sharedInstance].isShutdown) {
        return false;
    }

    return [[NewRelicAgentInternal sharedInstance].analyticsController addBreadcrumb:name
                                                                      withAttributes:attributes];
}

#pragma mark - Event retention settings

/*
 * this method sets the maximum allowed age of an event before analytics data is sent to New Relic
 * this means: once any recorded event reaches this age, all event data will be transmitted on the next
 * harvest cycle.
 */
+ (void) setMaxEventBufferTime:(unsigned int)seconds {
    [[NewRelicAgentInternal sharedInstance].analyticsController setMaxEventBufferTime:seconds];
}
/*
 * this method sets the maximum number of events buffered by the agent.
 * this means: once this many events have been recorded, new events have a statistical chance of overwriting
 * previously recorded events in the buffer.
 */
+ (void) setMaxEventPoolSize:(unsigned int)size {
    [[NewRelicAgentInternal sharedInstance].analyticsController setMaxEventBufferSize:size];
}

/*
 * this method sets the maximum size for offline storage that the can be collected in the agent.
 * this means: once the maximum size has been met the agent will stop storing offline payloads until
 * more room is made.
 */
+ (void) setMaxOfflineStorageSize:(unsigned int)megabytes {
    [NRMAAgentConfiguration setMaxOfflineStorageSize:megabytes];

    [NRMAHarvestController setMaxOfflineStorageSize:megabytes];
}
#pragma mark - Hidden APIs


/*
 * This function is built for hybird support and bridging with the browser agent
 */
+ (NSDictionary*) keyAttributes {
    return [NRMAKeyAttributes keyAttributes: [NRMAAgentConfiguration connectionInformation]];
}

+  (void)setURLRegexRules:(NSDictionary<NSString *, NSString *>*)regexRules {
    NRMAURLTransformer *transformer = [[NRMAURLTransformer alloc] initWithRegexRules:regexRules];
    [NewRelicAgentInternal setURLTransformer:transformer];
}

@end
