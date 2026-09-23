//
// Created by Bryce Buchanan on 2/7/18.
// Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMANetworkFacade.h"
#import "NRTimer.h"
#import "NRLogger.h"
#import "NRMANetworkResponseData.h"
#import "NRMANetworkRequestData.h"
#import "NewRelicInternalUtils.h"
#import "NRMAThreadInfo.h"
#import "NRMATaskQueue.h"
#import "NRMAHTTPTransaction.h"
#import "NRMAFlags.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConnection+GZip.h"
#import <Connectivity/Payload.hpp>
#include <Connectivity/Facade.hpp>
#import "NRMAPayloadContainer+cppInterface.h"
#import "NRMAAnalytics.h"

#import "NRMAAnalytics+cppInterface.h"

#import "NewRelicAgentInternal.h"
#import "NRMAHTTPUtilities+cppInterface.h"

// Caller-supplied distributed-trace context, parsed out of the W3C trace headers that a
// cross-platform agent (e.g. Flutter) hands to the notice* APIs. Every field is nil/0 when
// the headers did not carry it, so applying a context never clobbers a value with a blank.
@interface NRMACallerTraceContext : NSObject
@property (nonatomic, strong) NSString* traceId;
@property (nonatomic, strong) NSString* spanId;
@property (nonatomic, strong) NSString* accountId;
@property (nonatomic, strong) NSString* appId;
@property (nonatomic, strong) NSString* trustedAccountKey;
// Milliseconds since the epoch, 0 when absent. The two payload types disagree on units:
// NRMAPayload.timestamp is in seconds, Connectivity::Payload's is in milliseconds.
@property (nonatomic) long long timestampMillis;
@end

@implementation NRMACallerTraceContext
@end

// An all-zero traceparent carries no trace (W3C trace-context, section 3.2.2.3).
static NSString* const kNRMAInvalidTraceId = @"00000000000000000000000000000000";
static NSString* const kNRMAInvalidSpanId  = @"0000000000000000";

@implementation NRMANetworkFacade {

}

+ (int) insightsAttributeSizeLimit {
    return NRMA_INSIGHTS_ATTRIBUTE_SIZE_LIMIT;
}

+ (NSString*) generateResponseBody:(NSData*)responseBody
                         sizeLimit:(int)sizeLimit {
    if (responseBody.length > sizeLimit) {
        responseBody = [responseBody subdataWithRange:NSMakeRange(0,
                                                                  sizeLimit)];
    }
    return [[NSString alloc] initWithData:responseBody
                                 encoding:NSUTF8StringEncoding];
}

+ (NSString*) getAppDataHeader:(NSURLResponse*)response {
    return [response isKindOfClass:[NSHTTPURLResponse class]]?[((NSHTTPURLResponse*)response) allHeaderFields][NEW_RELIC_SERVER_METRICS_HEADER_KEY]:@"";
}


+ (NSDictionary*) headers:(NSURLResponse*)response {
    return [response isKindOfClass:[NSHTTPURLResponse class]]?[((NSHTTPURLResponse*)response) allHeaderFields]:@{};
}

+ (NSInteger) statusCode:(NSURLResponse*)response {
    return [response isKindOfClass:[NSHTTPURLResponse class]]?[((NSHTTPURLResponse*)response) statusCode]:0;
}

+ (NSString*) contentType:(NSURLResponse*)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSString* contentType = [((NSHTTPURLResponse*)response) allHeaderFields][@"Content-Type"];
        if (contentType.length && contentType.length < DEFAULT_RESPONSE_CONTENT_TYPE_LIMIT) {
            return contentType;
        }
    }
    return nil;
}

+ (NSString*) contentLength:(NSURLResponse*)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        return [((NSHTTPURLResponse*)response) allHeaderFields][@"Content-Length"];
    }
    return nil;
}

+ (NSString*) responseBodyForEvents:(NSData*)responseData {
    if ([NRMAFlags shouldEnableHttpResponseBodyCapture] && responseData) {
        return [NRMANetworkFacade generateResponseBody:responseData
                                             sizeLimit:[NRMANetworkFacade insightsAttributeSizeLimit]];
    } else if (![NRMAFlags shouldEnableHttpResponseBodyCapture]) {
        return @"NEWRELIC_RESPONSE_BODY_CAPTURE_DISABLED";
    }
    return @"";

}


+ (void) configureNRMAPayloadWithTraceHeaders:(NRMAPayload*)payload
                                  traceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders {
    if (!traceHeaders || !payload) {
        return;
    }

    NSString *traceParent = traceHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    
    if (!traceParent || ![traceParent isKindOfClass:[NSString class]]) {
        return;
    }
    
    NSArray<NSString*> *traceParentComponents = [traceParent componentsSeparatedByString:@"-"];

    if ([traceParentComponents count] > 2) {
        payload.traceId = traceParentComponents[1];
        payload.parentId = @"0";
        payload.id = traceParentComponents[2];
        payload.dtEnabled = true;
    } else {
        NRLOG_AGENT_WARNING(@"Invalid traceComponents. Skipping distributed tracing.");
    }
}

+ (void) configureCppPayloadWithTraceHeaders:(std::unique_ptr<NewRelic::Connectivity::Payload>&)payload
                                traceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders {
    if (!traceHeaders || !payload) {
        return;
    }

    NSString *traceParent = traceHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    
    if (!traceParent || ![traceParent isKindOfClass:[NSString class]]) {
        return;
    }  
    
    NSArray<NSString*> *traceParentComponents = [traceParent componentsSeparatedByString:@"-"];

    if ([traceParentComponents count] > 2) {
        payload->setTraceId(traceParentComponents[1].UTF8String);
        payload->setParentId(@"0".UTF8String);
        payload->setId(traceParentComponents[2].UTF8String);
        payload->setDistributedTracing(true);
    } else {
        NRLOG_AGENT_WARNING(@"Invalid traceComponents. Skipping distributed tracing.");
    }
}

+ (NSString*) component:(NSArray<NSString*>*)components atIndex:(NSUInteger)index {
    if (index >= components.count) {
        return nil;
    }
    NSString* value = components[index];
    return value.length ? value : nil;
}

// The NR tracestate entry carries the payload's creation time. Cross-platform agents write
// it in milliseconds (the distributed-tracing spec's unit); this agent's own W3CTraceState
// writes NRMAPayload.timestamp, which is in seconds. Tell the two apart by magnitude -- a
// millisecond value for any plausible date has at least 12 digits.
+ (long long) timestampMillisFromTraceStateField:(NSString*)field {
    if (!field.length) {
        return 0;
    }

    long long value = [field longLongValue];
    if (value <= 0) {
        return 0;
    }
    return (value >= 100000000000LL) ? value : (value * 1000);
}

// Fills in the account, application, trusted-account-key and timestamp the caller put in
// its tracestate header: "<trustedAccountKey>@nr=<version>-<parentType>-<accountId>-<appId>-
// <spanId>-<transactionId>-<sampled>-<priority>-<timestamp>".
+ (void) applyTraceStateHeader:(NSString*)traceState
                     toContext:(NRMACallerTraceContext*)context {
    if (![traceState isKindOfClass:[NSString class]] || !traceState.length) {
        return;
    }

    // tracestate may hold entries from several vendors: "congo=t61rcWkgMzE,1@nr=0-2-...".
    for (NSString* entry in [traceState componentsSeparatedByString:@","]) {
        NSRange separator = [entry rangeOfString:@"="];
        if (separator.location == NSNotFound) {
            continue;
        }

        NSString* key = [[entry substringToIndex:separator.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![key hasSuffix:@"@nr"]) {
            continue;
        }

        NSString* trustedAccountKey = [key substringToIndex:key.length - @"@nr".length];
        if (trustedAccountKey.length) {
            context.trustedAccountKey = trustedAccountKey;
        }

        NSArray<NSString*>* fields = [[entry substringFromIndex:NSMaxRange(separator)] componentsSeparatedByString:@"-"];
        context.accountId = [NRMANetworkFacade component:fields atIndex:2];
        context.appId = [NRMANetworkFacade component:fields atIndex:3];
        context.timestampMillis = [NRMANetworkFacade timestampMillisFromTraceStateField:[NRMANetworkFacade component:fields atIndex:8]];
        return;
    }
}

// Parses the caller-supplied trace headers into the trace context they describe. Returns nil
// when they carry no usable trace identity, in which case no distributed-trace context
// should be attached to the event at all -- a natively generated one would report a trace
// that matches nothing on the wire.
+ (NRMACallerTraceContext*) callerTraceContextFromTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders {
    if (![traceHeaders isKindOfClass:[NSDictionary class]] || !traceHeaders.count) {
        return nil;
    }

    NSString* traceParent = traceHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    if (![traceParent isKindOfClass:[NSString class]]) {
        NRLOG_AGENT_WARNING(@"Supplied trace headers carry no traceparent. Skipping distributed tracing.");
        return nil;
    }

    // traceparent: "<version>-<traceId>-<spanId>-<traceFlags>".
    NSArray<NSString*>* traceParentComponents = [traceParent componentsSeparatedByString:@"-"];
    NSString* traceId = [NRMANetworkFacade component:traceParentComponents atIndex:1];
    NSString* spanId = [NRMANetworkFacade component:traceParentComponents atIndex:2];

    if (!traceId || !spanId ||
        [traceId isEqualToString:kNRMAInvalidTraceId] ||
        [spanId isEqualToString:kNRMAInvalidSpanId]) {
        NRLOG_AGENT_WARNING(@"Invalid traceComponents. Skipping distributed tracing.");
        return nil;
    }

    NRMACallerTraceContext* context = [NRMACallerTraceContext new];
    context.traceId = traceId;
    context.spanId = spanId;
    [NRMANetworkFacade applyTraceStateHeader:traceHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY]
                                  toContext:context];
    return context;
}

+ (void) applyCallerTraceContext:(NRMACallerTraceContext*)context
                   toNRMAPayload:(NRMAPayload*)payload {
    if (!context || !payload) {
        return;
    }

    payload.traceId = context.traceId;
    payload.id = context.spanId;
    payload.parentId = @"0";
    payload.dtEnabled = true;

    if (context.accountId) {
        payload.accountId = context.accountId;
    }
    if (context.appId) {
        payload.appId = context.appId;
    }
    if (context.trustedAccountKey) {
        payload.trustedAccountKey = context.trustedAccountKey;
    }
    if (context.timestampMillis > 0) {
        payload.timestamp = context.timestampMillis / 1000.0;
    }
}

+ (void) applyCallerTraceContext:(NRMACallerTraceContext*)context
                    toCppPayload:(std::unique_ptr<NewRelic::Connectivity::Payload>&)payload {
    if (!context || !payload) {
        return;
    }

    payload->setTraceId(context.traceId.UTF8String);
    payload->setId(context.spanId.UTF8String);
    payload->setParentId("0");
    payload->setDistributedTracing(true);

    if (context.accountId) {
        payload->setAccountId(context.accountId.UTF8String);
    }
    if (context.appId) {
        payload->setAppId(context.appId.UTF8String);
    }
    if (context.trustedAccountKey) {
        payload->setTrustedAccountKey(context.trustedAccountKey.UTF8String);
    }
    if (context.timestampMillis > 0) {
        payload->setTimestamp(context.timestampMillis);
    }
}

+ (void) noticeNetworkRequest:(NSURLRequest*)request
                     response:(NSURLResponse*)response
                    withTimer:(NRTimer*)timer
                    bytesSent:(NSUInteger)bytesSent
                bytesReceived:(NSUInteger)bytesReceived
                 responseData:(NSData*)responseData
                 traceHeaders:(NSDictionary<NSString*,NSString*>* _Nullable)traceHeaders
                       params:(NSDictionary*)params {

    [timer stopTimer];
    double startTime = timer.startTimeInMillis;
    double duration = timer.timeElapsedInMilliSeconds;

    if (![NRMANetworkFacade canInstrumentRequestWithUrl:request.URL
                                          withStartTime:startTime
                                           withDuration:duration]) {
        return;
    }

    __block NRMAPayload* retrievedPayload;
    if([NRMAFlags shouldEnableNewEventSystem]){
        retrievedPayload = [NRMAHTTPUtilities retrieveNRMAPayload:request];
    }
    __block NRMAThreadInfo* threadInfo = [NRMAThreadInfo new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {

#if TARGET_OS_TV
        NSString* connectionType = [NewRelicInternalUtils connectionType];
#else
        // getCurrentWanType shouldn't be called on the main thread.
        NSString* connectionType = [NewRelicInternalUtils getCurrentWanType];
#endif
        NRMAURLTransformer *transformer = [NewRelicAgentInternal getURLTransformer];
        NSURL *replacedURL = [transformer transformURL:request.URL];
        if(!replacedURL) {
            replacedURL = request.URL;
        }

        NRMANetworkRequestData* networkRequestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:replacedURL
                                                                                             httpMethod:[request HTTPMethod]
                                                                                         connectionType:connectionType
                                                                                            contentType:[NRMANetworkFacade contentType:response]
                                                                                              bytesSent:bytesSent];
        if (params) {
            [NRMAHTTPUtilities addHTTPHeaderTrackingFor:params.allKeys];

            NSMutableDictionary *paramsAndHeaders = [NSMutableDictionary dictionaryWithDictionary:params];
            [paramsAndHeaders addEntriesFromDictionary:request.allHTTPHeaderFields];
            [NRMAHTTPUtilities addTrackedHeaders:paramsAndHeaders to:networkRequestData];

        }
        else {
            [NRMAHTTPUtilities addTrackedHeaders:request.allHTTPHeaderFields to:networkRequestData];
        }

        NSUInteger modifiedBytesReceived = bytesReceived;
        if([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
            NSString* header = httpResponse.allHeaderFields[@"Content-Encoding"];
            if ([header isEqualToString:@"gzip"]) {
                modifiedBytesReceived = [[NRMAHarvesterConnection gzipData:responseData] length];
            }
        }
        // NR-586680: when a cross-platform caller (e.g. the Flutter agent) supplies the
        // trace headers, that caller owns the distributed trace, so report the event
        // against its trace context -- creating a payload to carry that context if the
        // request has none attached. When the headers carry no usable trace identity,
        // leave the request's own payload alone instead of generating a native trace that
        // would match nothing on the wire.
        NRMACallerTraceContext* callerTrace = [NRMANetworkFacade callerTraceContextFromTraceHeaders:traceHeaders];
        std::unique_ptr<NewRelic::Connectivity::Payload> retrievedCppPayload;
        if([NRMAFlags shouldEnableNewEventSystem]){
            if(callerTrace) {
                if(retrievedPayload == nil) {
                    retrievedPayload = [NRMAHTTPUtilities generateNRMAPayload];
                }
                [NRMANetworkFacade applyCallerTraceContext:callerTrace toNRMAPayload:retrievedPayload];
            }
        } else {
            retrievedCppPayload = [NRMAHTTPUtilities retrievePayload:request];
            if(callerTrace) {
                if(retrievedCppPayload == nullptr) {
                    retrievedCppPayload = NewRelic::Connectivity::Facade::getInstance().newPayload();
                }
                [NRMANetworkFacade applyCallerTraceContext:callerTrace toCppPayload:retrievedCppPayload];
            }
        }

        // Failure case
        if ([NRMANetworkFacade statusCode:response] >= NRMA_HTTP_STATUS_CODE_ERROR_THRESHOLD) {
            if([NRMAFlags shouldEnableNewEventSystem]){
                [[[NewRelicAgentInternal sharedInstance] analyticsController] addHTTPErrorEvent:networkRequestData
                                                                                   withResponse:[[NRMANetworkResponseData alloc] initWithHttpError:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds] networkErrorMessage:nil encodedResponseBody:[NRMANetworkFacade responseBodyForEvents:responseData] appDataHeader:[NRMANetworkFacade getAppDataHeader:response]]
                                                                                withNRMAPayload:retrievedPayload];
            } else {
                [[[NewRelicAgentInternal sharedInstance] analyticsController] addHTTPErrorEvent:networkRequestData
                                                                                   withResponse:[[NRMANetworkResponseData alloc] initWithHttpError:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds] networkErrorMessage:nil encodedResponseBody:[NRMANetworkFacade responseBodyForEvents:responseData] appDataHeader:[NRMANetworkFacade getAppDataHeader:response]]
                                                                                    withPayload:std::move(retrievedCppPayload)];
            }
        // Success case
        } else {
            if([NRMAFlags shouldEnableNewEventSystem]){
                [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkRequestEvent:networkRequestData
                                                                                        withResponse:[[NRMANetworkResponseData alloc] initWithSuccessfulResponse:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds]]
                                                                                     withNRMAPayload: retrievedPayload];
            } else {
                [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkRequestEvent:networkRequestData
                                                                                        withResponse:[[NRMANetworkResponseData alloc] initWithSuccessfulResponse:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds]]
                                                                                         withPayload:std::move(retrievedCppPayload)];
            }
        }

        [NRMATaskQueue queue:[[NRMAHTTPTransaction alloc] initWithURL:replacedURL.absoluteString
                                                           httpMethod:[request HTTPMethod]
                                                            startTime:startTime
                                                            totalTime:duration
                                                            bytesSent:bytesSent
                                                        bytesReceived:modifiedBytesReceived
                                                           statusCode:(int)[NRMANetworkFacade statusCode:response]
                                                          failureCode:0
                                                              appData:[NRMANetworkFacade getAppDataHeader:response]
                                                              wanType:connectionType
                                                           threadInfo:threadInfo]];

        // Force a dequeue immediately. (no waiting 1 second for auto dequeue.)
        [NRMATaskQueue synchronousDequeue];
    });
}

+ (void) noticeNetworkFailure:(NSURLRequest*)request
                    withTimer:(NRTimer*)timer
                    withError:(NSError*)error {

    [timer stopTimer];
    double startTime = timer.startTimeInMillis;
    double duration = timer.timeElapsedInMilliSeconds;

    if (![NRMANetworkFacade canInstrumentFailedRequestWithUrl:request.URL
                                                withStartTime:startTime
                                                 withDuration:duration]) {
        return;
    }

    __block NRMAPayload* retrievedPayload;
    __block NRMAThreadInfo* threadInfo = [NRMAThreadInfo new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
#if TARGET_OS_TV
        NSString* connectionType = [NewRelicInternalUtils connectionType];
#else
        // getCurrentWanType shouldn't be called on the main thread.
        NSString* connectionType = [NewRelicInternalUtils getCurrentWanType];
#endif
        
        NRMAURLTransformer *transformer = [NewRelicAgentInternal getURLTransformer];
        NSURL *replacedURL = [transformer transformURL:request.URL];
        if(!replacedURL) {
            replacedURL = request.URL;
        }

        NRMANetworkRequestData* networkRequestData = [[NRMANetworkRequestData alloc]initWithRequestUrl:replacedURL
                                                                                            httpMethod:[request HTTPMethod]
                                                                                        connectionType:connectionType
                                                                                           contentType:[request allHTTPHeaderFields][@"Content-Type"]
                                                                                             bytesSent:0];
        [NRMAHTTPUtilities addTrackedHeaders:request.allHTTPHeaderFields to:networkRequestData];

        NSDictionary<NSString*,NSString*>*  traceHeaders;
    
        

        if([NRMAFlags shouldEnableNewEventSystem]){
            if(retrievedPayload == nil) {
                retrievedPayload = [NRMAHTTPUtilities generateNRMAPayload];
            }
            traceHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithNRMAPayload:retrievedPayload];
            
            if(traceHeaders) {

                [NRMANetworkFacade configureNRMAPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
            }

            [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkErrorEvent:networkRequestData
                                                                                  withResponse:[[NRMANetworkResponseData alloc]
                                                                                                initWithNetworkError:error.code
                                                                                                bytesReceived:0
                                                                                                responseTime:timer.timeElapsedInSeconds
                                                                                                networkErrorMessage:error.localizedDescription]
                                                                               withNRMAPayload:retrievedPayload];
        }
        else {
            std::unique_ptr<NewRelic::Connectivity::Payload> retrievedCppPayload = [NRMAHTTPUtilities retrievePayload:request];
            if(retrievedCppPayload == nullptr) {
                retrievedCppPayload = NewRelic::Connectivity::Facade::getInstance().newPayload();
            }
            traceHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:[NRMAHTTPUtilities generatePayload]];

            if(traceHeaders) {
                [NRMANetworkFacade configureCppPayloadWithTraceHeaders:retrievedCppPayload traceHeaders:traceHeaders];
            }

            [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkErrorEvent:networkRequestData
                                                                                  withResponse:[[NRMANetworkResponseData alloc]
                                                                                                initWithNetworkError:error.code
                                                                                                bytesReceived:0
                                                                                                responseTime:timer.timeElapsedInSeconds
                                                                                                networkErrorMessage:error.localizedDescription]
                                                                                   withPayload:std::move(retrievedCppPayload)];
        }

         // getCurrentWanType shouldn't be called on the main thread because it calls a blocking method to get connection flags
        [NRMATaskQueue queue:[[NRMAHTTPTransaction alloc] initWithURL:replacedURL.absoluteString
                                                           httpMethod:[request HTTPMethod]
                                                            startTime:startTime
                                                            totalTime:duration
                                                            bytesSent:0
                                                        bytesReceived:0
                                                           statusCode:0
                                                          failureCode:(int)error.code
                                                              appData:nil
                                                              wanType:connectionType
                                                           threadInfo:threadInfo]];
        // Force a dequeue immediately. (no waiting 1 second for auto dequeue.)
        [NRMATaskQueue synchronousDequeue];
    });
}

+ (bool) canInstrumentRequestWithUrl:(NSURL*)url
                       withStartTime:(double)startTime
                        withDuration:(double)duration {
    return [NRMANetworkFacade canInstrumentRequest:@"network request"
                                           withUrl:url
                                     withStartTime:startTime
                                      withDuration:duration];
}

+ (bool) canInstrumentFailedRequestWithUrl:(NSURL*)url
                             withStartTime:(double)startTime
                              withDuration:(double)duration {
    return [NRMANetworkFacade canInstrumentRequest:@"failed request"
                                           withUrl:url
                                     withStartTime:startTime
                                      withDuration:duration];
}

+ (bool) canInstrumentRequest:(NSString*)loggingKey
                      withUrl:(NSURL*)url
                withStartTime:(double)startTime
                 withDuration:(double)duration {
    bool canInstrument = true;

    if (!url) {
        NRLOG_AGENT_WARNING(@"Ignoring %@ with a nil URL.", loggingKey);
        canInstrument = false;
    }
    if (url.absoluteString.length < 10) {
        NRLOG_AGENT_WARNING(@"Ignoring %@ with an invalid URL: %@", loggingKey, url.absoluteString);
        canInstrument = false;
    }
    if (startTime <= 0) {
        NRLOG_AGENT_WARNING(@"Ignoring %@ with invalid start time (%lf): %@",
                      loggingKey,
                      startTime,
                      url.absoluteString);
        canInstrument = false;
    }
    if (duration < 0) {
        NRLOG_AGENT_WARNING(@"Ignoring %@ with negative duration (%lf): %@",
                      loggingKey,
                      duration,
                      url.absoluteString);
        canInstrument = false;
    }

    return canInstrument;
}

+ (int) responseBodyCaptureSizeLimit {
    NRMAHarvesterConfiguration* config = [NRMAHarvestController configuration];
    if (config == nil) {
        return 0;
    }
    return config.response_body_limit;
}

- (NSString*) crossProcessId {
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvester* harvester = [controller harvester];
    return harvester ? [harvester crossProcessID] : nil;
}

@end
