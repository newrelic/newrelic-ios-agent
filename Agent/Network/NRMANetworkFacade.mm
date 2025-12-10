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
        // Failure case
        if ([NRMANetworkFacade statusCode:response] >= NRMA_HTTP_STATUS_CODE_ERROR_THRESHOLD) {
            if([NRMAFlags shouldEnableNewEventSystem]){
                if(traceHeaders) {
                    if(retrievedPayload == nil) {
                        retrievedPayload = [NRMAHTTPUtilities generateNRMAPayload];
                    }
                    [NRMANetworkFacade configureNRMAPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
                }

                [[[NewRelicAgentInternal sharedInstance] analyticsController] addHTTPErrorEvent:networkRequestData
                                                                                   withResponse:[[NRMANetworkResponseData alloc] initWithHttpError:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds] networkErrorMessage:nil encodedResponseBody:[NRMANetworkFacade responseBodyForEvents:responseData] appDataHeader:[NRMANetworkFacade getAppDataHeader:response]]
                                                                                withNRMAPayload:retrievedPayload];
            } else {
                std::unique_ptr<NewRelic::Connectivity::Payload> retrievedPayload = [NRMAHTTPUtilities retrievePayload:request];
                if(traceHeaders) {
                    if(retrievedPayload == nullptr) {
                        retrievedPayload = NewRelic::Connectivity::Facade::getInstance().newPayload();
                    }
                    [NRMANetworkFacade configureCppPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
                }

                [[[NewRelicAgentInternal sharedInstance] analyticsController] addHTTPErrorEvent:networkRequestData
                                                                                   withResponse:[[NRMANetworkResponseData alloc] initWithHttpError:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds] networkErrorMessage:nil encodedResponseBody:[NRMANetworkFacade responseBodyForEvents:responseData] appDataHeader:[NRMANetworkFacade getAppDataHeader:response]]
                                                                                    withPayload:std::move(retrievedPayload)];
            }
        // Success case
        } else {
            if([NRMAFlags shouldEnableNewEventSystem]){
                if(traceHeaders) {
                    if(retrievedPayload == nil) {
                        retrievedPayload = [NRMAHTTPUtilities generateNRMAPayload];
                    }
                    [NRMANetworkFacade configureNRMAPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
                }

                [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkRequestEvent:networkRequestData
                                                                                        withResponse:[[NRMANetworkResponseData alloc] initWithSuccessfulResponse:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds]]
                                                                                     withNRMAPayload: retrievedPayload];
            } else {
                std::unique_ptr<NewRelic::Connectivity::Payload> retrievedPayload = [NRMAHTTPUtilities retrievePayload:request];
                if(traceHeaders) {
                    if(retrievedPayload == nullptr) {
                        retrievedPayload = NewRelic::Connectivity::Facade::getInstance().newPayload();
                    }
                    [NRMANetworkFacade configureCppPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
                }

                [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkRequestEvent:networkRequestData
                                                                                        withResponse:[[NRMANetworkResponseData alloc] initWithSuccessfulResponse:[NRMANetworkFacade statusCode:response] bytesReceived:modifiedBytesReceived responseTime:[timer timeElapsedInSeconds]]
                                                                                         withPayload:std::move(retrievedPayload)];
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
            traceHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithNRMAPayload:[NRMAHTTPUtilities generateNRMAPayload]];
        } else {
            traceHeaders =  [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:[NRMAHTTPUtilities generatePayload]];
        }
        

        if([NRMAFlags shouldEnableNewEventSystem]){
            if(traceHeaders) {
                if(retrievedPayload == nil) {
                    retrievedPayload = [NRMAHTTPUtilities generateNRMAPayload];
                }
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
            std::unique_ptr<NewRelic::Connectivity::Payload> retrievedPayload = [NRMAHTTPUtilities retrievePayload:request];
            if(traceHeaders) {
                if(retrievedPayload == nullptr) {
                    retrievedPayload = NewRelic::Connectivity::Facade::getInstance().newPayload();
                }
                [NRMANetworkFacade configureCppPayloadWithTraceHeaders:retrievedPayload traceHeaders:traceHeaders];
            }

            [[[NewRelicAgentInternal sharedInstance] analyticsController] addNetworkErrorEvent:networkRequestData
                                                                                  withResponse:[[NRMANetworkResponseData alloc]
                                                                                                initWithNetworkError:error.code
                                                                                                bytesReceived:0
                                                                                                responseTime:timer.timeElapsedInSeconds
                                                                                                networkErrorMessage:error.localizedDescription]
                                                                                   withPayload:std::move(retrievedPayload)];
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
    return [NRMAHarvestController configuration].response_body_limit;
}

- (NSString*) crossProcessId {
    return [[[NRMAHarvestController harvestController] harvester] crossProcessID];
}

@end
