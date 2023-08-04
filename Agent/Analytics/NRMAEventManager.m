//
//  NRMAEventManager.m
//  Agent
//
//  Created by Steve Malsam on 6/7/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAEventManager.h"

#import "NRLogger.h"
#import "NRMAJSON.h"
#import "NRMARequestEvent.h"
#include "Analytics/Constants.hpp"
#import "NRMANetworkErrorEvent.h"

static const NSUInteger kDefaultBufferSize = 1000;
static const NSUInteger kDefaultBufferTimeSeconds = 600; // 5 Minutes
static const NSUInteger kMinBufferTimeSeconds = 60; // 60 seconds

@implementation NRMAEventManager {
    NSMutableArray<NRMAAnalyticEventProtocol> *events;
    
    NSUInteger maxBufferSize;
    NSUInteger maxBufferTimeSeconds;
    
    NSUInteger totalAttemptedInserts;
    NSTimeInterval oldestEventTimestamp;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        events = [[NSMutableArray alloc] init];
        maxBufferSize = kDefaultBufferSize;
        maxBufferTimeSeconds = kDefaultBufferTimeSeconds;
        totalAttemptedInserts = 0;
        oldestEventTimestamp = 0;
    }
    return self;
}

- (void)setMaxEventBufferSize:(NSUInteger)size {
    maxBufferSize = size;
}

- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds {
    if(seconds < kMinBufferTimeSeconds) {
        NRLOG_ERROR(@"Buffer Time cannot be less than %lu Seconds", (unsigned long)kMinBufferTimeSeconds);
        maxBufferTimeSeconds = kMinBufferTimeSeconds;
    } else if (seconds > kDefaultBufferTimeSeconds){
        NRLOG_WARNING(@"Buffer Time should not be longer than %lu seconds", (unsigned long)kDefaultBufferTimeSeconds);
        maxBufferTimeSeconds = kDefaultBufferTimeSeconds;
    }
    
    maxBufferTimeSeconds = seconds;
}

- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds {
    if(oldestEventTimestamp == 0) {
        return false;
    }
    
    NSTimeInterval oldestEventAge = currentTimeMilliseconds - oldestEventTimestamp;
    return (oldestEventAge / 1000) >= maxBufferTimeSeconds;
}

- (NSUInteger)getEvictionIndex {
    if(totalAttemptedInserts > 0) {
        return arc4random() % totalAttemptedInserts;
    } else {
        return 0;
    }
}

- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event {
    @synchronized (events) {
        // The event fits within the buffer
        if (events.count < maxBufferSize) {
            [events addObject:event];
            if(events.count == 1) {
                oldestEventTimestamp = event.timestamp;
            }
        } else {
            // we need to throw away an event. We try to balance
            // between evicting newer events and older events.
            NSUInteger evictionIndex = [self getEvictionIndex];
            if (evictionIndex < events.count) {
                [events removeObjectAtIndex:evictionIndex];
                [events addObject:event];
            }
        }
    }
    totalAttemptedInserts++;
    return YES;
}

- (BOOL)addRequestEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
            withPayload:(NRMAPayload *)payload {

    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
        NSTimeInterval currentTime_ms = [[[NSDate alloc] init] timeIntervalSince1970];
        NSTimeInterval sessionDuration_sec = (currentTime_ms - payload.timestamp)/1000; // TODO: Make sure it's ok to use payload timestamp
        
        NRMARequestEvent *event = [[NRMARequestEvent alloc] initWithTimestamp:currentTime_ms sessionElapsedTimeInSeconds:sessionDuration_sec payload:payload withAttributeValidator:nil]; //TODO: need a real AttributeValidator?
        if (event == nil) {
            return false;
        }
        
        NSString* requestUrl = requestData.requestUrl;
        NSString* requestDomain = requestData.requestDomain;
        NSString* requestPath = requestData.requestPath;
        NSString* requestMethod = requestData.requestMethod;
        NSString* connectionType = requestData.connectionType;
        NSNumber* bytesSent = @(requestData.bytesSent);
        NSString* contentType = requestData.contentType;
        NSNumber *responseTime = @(responseData.timeInSeconds);
        NSNumber* bytesReceived = @(responseData.bytesReceived);
        NSNumber* statusCode = @(responseData.statusCode);
        
        if ((requestUrl.length == 0)) {
            NRLOG_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return false;
        }
        
        [event addAttribute:@(__kNRMA_Attrib_requestUrl) value:requestUrl];
        [event addAttribute:@(__kNRMA_Attrib_responseTime) value:responseTime];
        
        if (addDistributedTracing) {
            [event addAttribute:@(__kNRMA_Attrib_dtGuid) value:distributedTracingId];
            [event addAttribute:@(__kNRMA_Attrib_dtId) value:distributedTracingId];
            [event addAttribute:@(__kNRMA_Attrib_dtTraceId) value:traceId];
        }
        
        if ((requestDomain.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestDomain) value:requestDomain];
        }
        
        if ((requestPath.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestPath) value:requestPath];
        }
        
        if ((requestMethod.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestMethod) value:requestMethod];
        }
        
        if ((connectionType.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_connectionType) value:connectionType];
        }
        
        if (bytesReceived != 0) {
            [event addAttribute:@(__kNRMA_Attrib_bytesReceived) value:bytesReceived];
        }
        
        if (bytesSent != 0) {
            [event addAttribute:@(__kNRMA_Attrib_bytesSent) value:bytesSent];
        }
        
        if (statusCode != 0) {
            [event addAttribute:@(__kNRMA_Attrib_statusCode) value:statusCode];
        }
        
        if ((contentType.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_contentType) value:contentType];
        }
        
        return [self addEvent:event];
    } @catch (NSException *exception) {
        NRLOG_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    } @finally {
        NRLOG_ERROR(@"Failed to add Network Error Event.");
    }
}

- (BOOL)addHTTPErrorEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
              withPayload:(NRMAPayload *)payload {
    
    return [self addEvent:[self createErrorEvent:requestData withResponse:responseData withPayload:payload]];
}

- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
              withPayload:(NRMAPayload *)payload {
    
    return [self addEvent:[self createErrorEvent:requestData withResponse:responseData withPayload:payload]];
}

- (id<NRMAAnalyticEventProtocol>)createErrorEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
             withPayload:(NRMAPayload *)payload {
    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
        NSTimeInterval currentTime_ms = [[[NSDate alloc] init] timeIntervalSince1970];
        NSTimeInterval sessionDuration_sec = 0.0 ; //TODO: need to calculate session duration getCurrentSessionDuration_sec(currentTime_ms);
        
        NSString* requestUrl = requestData.requestUrl;
        NSString* requestDomain = requestData.requestDomain;
        NSString* requestPath = requestData.requestPath;
        NSString* requestMethod = requestData.requestMethod;
        NSString* connectionType = requestData.connectionType;
        NSNumber* bytesSent = @(requestData.bytesSent);
        NSString* contentType = requestData.contentType;
        NSString* appDataHeader = responseData.appDataHeader;
        NSString* encodedResponseBody = responseData.encodedResponseBody;
        NSString* networkErrorMessage = responseData.errorMessage;
        NSNumber* networkErrorCode = @(responseData.networkErrorCode);
        NSNumber *responseTime = @(responseData.timeInSeconds);
        NSNumber* bytesReceived = @(responseData.bytesReceived);
        NSNumber* statusCode = @(responseData.statusCode);
        
        if ((requestUrl.length == 0)) {
            NRLOG_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return false;
        }
        
        NRMANetworkErrorEvent *event = [[NRMANetworkErrorEvent alloc] initWithTimestamp:currentTime_ms sessionElapsedTimeInSeconds:sessionDuration_sec encodedResponseBody:encodedResponseBody appDataHeader:appDataHeader payload:payload withAttributeValidator:nil]; //TODO: need a real AttributeValidator?
        if (event == nil) {
            return false;
        }
        
        [event addAttribute:@(__kNRMA_Attrib_requestUrl) value:requestUrl];
        [event addAttribute:@(__kNRMA_Attrib_responseTime) value:responseTime];
        
        if (addDistributedTracing) {
            [event addAttribute:@(__kNRMA_Attrib_dtGuid) value:distributedTracingId];
            [event addAttribute:@(__kNRMA_Attrib_dtId) value:distributedTracingId];
            [event addAttribute:@(__kNRMA_Attrib_dtTraceId) value:traceId];
        }
        
        if ((requestDomain.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestDomain) value:requestDomain];
        }
        
        if ((requestPath.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestPath) value:requestPath];
        }
        
        if ((requestMethod.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_requestMethod) value:requestMethod];
        }
        
        if ((connectionType.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_connectionType) value:connectionType];
        }
        
        if (bytesReceived != 0) {
            [event addAttribute:@(__kNRMA_Attrib_bytesReceived) value:bytesReceived];
        }
        
        if (bytesSent != 0) {
            [event addAttribute:@(__kNRMA_Attrib_bytesSent) value:bytesSent];
        }
        
        if (encodedResponseBody.length > 0) {
            [event addAttribute:@(__kNRMA_Attrib_networkError) value:networkErrorMessage];
        }
        
        if (networkErrorCode != 0) {
            [event addAttribute:@(__kNRMA_Attrib_networkErrorCode) value:networkErrorCode];
        }
        
        if (networkErrorMessage.length > 0) {
            [event addAttribute:@(__kNRMA_Attrib_networkError) value:networkErrorMessage];
        }
        
        if (statusCode != 0) {
            [event addAttribute:@(__kNRMA_Attrib_statusCode) value:statusCode];
        }
        
        if ((contentType.length > 0)) {
            [event addAttribute:@(__kNRMA_Attrib_contentType) value:contentType];
        }
        
        return event;
    } @catch (NSException *exception) {
        NRLOG_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    } @finally {
        NRLOG_ERROR(@"Failed to add Network Error Event.");
    }
}

- (void)empty {
    @synchronized (events) {
        [events removeAllObjects];
        oldestEventTimestamp = 0;
        totalAttemptedInserts = 0;
    }
}

- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error {
    NSString *eventJsonString = nil;
    @synchronized (events) {
        @try {
            NSMutableArray *jsonEvents = [[NSMutableArray alloc] init];
            for(id<NRMAAnalyticEventProtocol> event in events) {
                [jsonEvents addObject:[event JSONObject]];
            }
            
            NSData *eventJsonData = [NRMAJSON dataWithJSONObject:jsonEvents
                                                         options:0
                                                           error:error];
            eventJsonString = [[NSString alloc] initWithData:eventJsonData
                                                    encoding:NSUTF8StringEncoding];
        } @catch (NSException *e) {
            NRLOG_ERROR(@"FAILED TO CREATE EVENT JSON: %@", e.reason);
        }
    }
    return eventJsonString;
}

@end
