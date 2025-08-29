//
//  NRMANetworkUtilites.m
//  NewRelicAgent
//
//  Created on 8/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <iostream>
#include <sstream>

#include <Connectivity/Facade.hpp>

#import "NRMABase64.h"
#import "NRMAHTTPUtilities.h"
#import "NRMAHarvestController.h"
#import "NRMAFlags.h"
#import "NRMAPayloadContainer+cppInterface.h"
#import "NRMAAssociate.h"
#import "NRMANetworkFacade.h"
#import "NRMAPayloadContainer.h"
#import "NRMAMetric.h"
#import "NRMATaskQueue.h"
#import "NRConstants.h"
#import "NRMATraceContext.h"
#import "W3CTraceParent.h"
#import "W3CTraceState.h"
#import "NRLogger.h"
#import "NRMANetworkRequestData+CppInterface.h"
#include <Utilities/Application.hpp>
#import "NRMAHarvestController.h"

static NSArray* _trackedHeaderFields;

static NSString* _operationName = @"X-APOLLO-OPERATION-NAME";
static NSString* _operationType = @"X-APOLLO-OPERATION-TYPE";
static NSString* _operationId = @"X-APOLLO-OPERATION-ID";

@implementation NRMAHTTPUtilities
//NSString* currentTraceId = @"";
NSString* currentParentId = @"";

+ (NSArray*) trackedHeaderFields
{
    static dispatch_once_t defaultFeatureToken;
    dispatch_once(&defaultFeatureToken,
                  ^{
        _trackedHeaderFields = (NSArray*)@[_operationName,
                                           _operationType,
                                           _operationId];
                  });

    return _trackedHeaderFields;
}

+ (NSMutableURLRequest*) addCrossProcessIdentifier:(NSURLRequest*)request {

    NSMutableURLRequest* mutableRequest = [self makeMutable:request];

    NSString* xprocess = [NRMAHarvestController configuration].cross_process_id;

    if (xprocess.length) {
        [mutableRequest setValue:xprocess
              forHTTPHeaderField:NEW_RELIC_CROSS_PROCESS_ID_HEADER_KEY];
    }

    return mutableRequest;
}

+ (NSMutableURLRequest*) makeMutable:(NSURLRequest*)request {
    __autoreleasing NSMutableURLRequest* mutableRequest = nil;
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        mutableRequest = (NSMutableURLRequest*)request;
    } else {
        // A copy is retained.
        mutableRequest = [request mutableCopy];
    }
    return mutableRequest;
}


+ (NSMutableURLRequest*) addConnectivityHeaderAndPayload:(NSURLRequest*)request {
    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities makeMutable:request];
    if([NRMAFlags shouldEnableNewEventSystem]){
        [NRMAHTTPUtilities attachNRMAPayload:[NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]
                                          to:mutableRequest];
    } else {
        [NRMAHTTPUtilities attachPayload:[NRMAHTTPUtilities addConnectivityHeader:mutableRequest]
                                      to:mutableRequest];
    }
    return mutableRequest;
}

+ (NRMAPayload*) addConnectivityHeaderNRMAPayload:(NSMutableURLRequest*)request {
    if(![NRMAFlags shouldEnableDistributedTracing]) { return nil; }
    
    NRMAPayload *payload = [NRMAHTTPUtilities generateNRMAPayload];
    if(payload == nil) { return nil; }
    
    NSDictionary<NSString*, NSString*> *connectivityHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithNRMAPayload:payload];
    
    if(connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY]
       forHTTPHeaderField:NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY];
    }
    
    BOOL dtError = false;
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    } else {
        dtError = true;
    }
    
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY];
    } else {
        dtError = true;
    }
        
    if (dtError) {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Exception"
                           value:@1
                       scope:@""]];
    } else {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Success"
                           value:@1
                       scope:@""]];
    }
    
    return payload;
}

+ (NRMAPayload *) generateNRMAPayload {
    NRMAPayload *payload = [NRMAHTTPUtilities startTrip];
    if(payload == nil) { return nil; }
    payload.dtEnabled = true;
    
    return payload;
}

+ (NRMAPayloadContainer*) addConnectivityHeader:(NSMutableURLRequest*)request {

    if(![NRMAFlags shouldEnableDistributedTracing]) { return nil; }
    
    NRMAPayloadContainer *payloadContainer = [NRMAHTTPUtilities generatePayload];
    if(payloadContainer == nil) { return nil; }
    
    NSDictionary<NSString*, NSString*> *connectivityHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:payloadContainer];
    
    if(connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY]
       forHTTPHeaderField:NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY];
    }
    
    BOOL dtError = false;
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    } else {
        dtError = true;
    }
    
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY];
    } else {
        dtError = true;
    }
        
    if (dtError) {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Exception"
                           value:@1
                       scope:@""]];
    } else {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Success"
                           value:@1
                       scope:@""]];
    }
        
    return payloadContainer;
}

+ (NRMAPayloadContainer *) generatePayload {
    std::unique_ptr<NewRelic::Connectivity::Payload> payload = nullptr;
    payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
    
    if(payload == nullptr) {
        NRLOG_ERROR(@"Not attaching distributed tracing because account or application id are missing.");
        return nil;
    }
    payload->setDistributedTracing(true);
    return [[NRMAPayloadContainer alloc] initWithPayload:std::move(payload)];
}

+ (NRMAPayload *) startTrip {
    if(!NewRelic::Application::getInstance().isValid()) {
        NRLOG_ERROR(@"Not attaching distributed tracing because account or application id are missing.");
        return nil;
    }
    
    @synchronized (self) {
        NSString * accountID = @(NewRelic::Application::getInstance().getContext().getAccountId().c_str());
        NSString * appId = @(NewRelic::Application::getInstance().getContext().getApplicationId().c_str());
        NSString * trustedAccountKey =  @(NewRelic::Application::getInstance().getContext().getTrustedAccountKey().c_str());
        NSTimeInterval currentTimeStamp = [[NSDate date] timeIntervalSince1970];

        NSString* currentTraceId = [[[[[NSUUID UUID] UUIDString] componentsSeparatedByString:@"-"] componentsJoinedByString:@""] lowercaseString];
        currentParentId = @"";
        
        NRMAPayload * payload;
        if(currentTraceId != nil && currentParentId != nil && accountID != nil && accountID.length > 0){
            payload = [[NRMAPayload alloc] initWithTimestamp:currentTimeStamp accountID:accountID appID:appId traceID:[NSString stringWithString:currentTraceId] parentID:[NSString stringWithString:currentParentId] trustedAccountKey:trustedAccountKey];
            currentParentId = [payload id];
        }
        return payload;
    }
}

+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithNRMAPayload:(NRMAPayload*)payload {
    if(payload == nil) {
        return @{};
    }
    NSDictionary *json;
    
    if(payload != nil) {
        json = [payload JSONObject];
    }
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithNRMAPayload:payload];
    NSString *traceParent = [W3CTraceParent headerFromContext:traceContext];
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *encodedPayloadHeader = [NRMABase64 encodeFromData:[NSJSONSerialization  dataWithJSONObject:json options:0 error:nil]];
    
    return @{NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY:encodedPayloadHeader,
             W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY:traceParent,
             W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY:traceState};
}

+ (void) attachNRMAPayload:(NRMAPayload*)payload to:(id)object {
    [NRMAAssociate attach:payload to:object with:kNRMA_ASSOCIATED_PAYLOAD_KEY];
}

+ (NRMAPayload*) retrieveNRMAPayload:(id)object {
    id associatedObject = [NRMAAssociate retrieveFrom:object
                                    with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    [NRMAAssociate removeFrom:object
                         with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    if ([associatedObject isKindOfClass:[NRMAPayload class]]) {

        return associatedObject;
    }

    return nil;
}

+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithPayload:(NRMAPayloadContainer*)payloadContainer {
    if(payloadContainer == nil) {
        return @{};
    }
    NSString *payloadHeader;
    const std::unique_ptr<NewRelic::Connectivity::Payload>& payload = [payloadContainer getReference];
    
    if(payload != nullptr) {
        auto json = payload->toJSON();
        std::stringstream s;
        s << json;
        
        payloadHeader = [NSString stringWithCString:s.str().c_str()
                                           encoding:NSUTF8StringEncoding];
    }
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload:payload];
    NSString *traceParent = [W3CTraceParent headerFromContext:traceContext];
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *encodedPayloadHeader = [NRMABase64 encodeFromData:[payloadHeader dataUsingEncoding:NSUTF8StringEncoding]];
    
    return @{NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY:encodedPayloadHeader,
             W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY:traceParent,
             W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY:traceState};
}

+ (void) attachPayload:(NRMAPayloadContainer*)payload to:(id)object {
    [NRMAAssociate attach:payload to:object with:kNRMA_ASSOCIATED_PAYLOAD_KEY];
}

+ (std::unique_ptr<NewRelic::Connectivity::Payload>) retrievePayload:(id)object {
    id associatedObject = [NRMAAssociate retrieveFrom:object
                                    with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    [NRMAAssociate removeFrom:object
                         with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    if ([associatedObject isKindOfClass:[NRMAPayloadContainer class]]) {

        return [((NRMAPayloadContainer* )associatedObject) pullPayload];
    }

    return std::unique_ptr<NewRelic::Connectivity::Payload>(nullptr);
}

+  (void)addHTTPHeaderTrackingFor:(NSArray *)headers {
    @synchronized (self) {
        NSMutableSet *combinedSet = [NSMutableSet setWithArray:[self trackedHeaderFields]];
        [combinedSet addObjectsFromArray:headers];
        _trackedHeaderFields = (NSArray *)[combinedSet allObjects];
    }
}

+ (NSString*) normalizeApolloHeaders:(NSString*) headerField {
    if ([headerField compare:_operationName] == NSOrderedSame) {
        headerField = @"operationName";
    } else if ([headerField compare:_operationType] == NSOrderedSame) {
        headerField = @"operationType";
    } else if ([headerField compare:_operationId] == NSOrderedSame) {
        headerField = @"operationId";
    }
    return headerField;
}

+ (void) addTrackedHeaders:(NSDictionary *)headers to:(NRMANetworkRequestData*)requestData {
    if (requestData == nil || headers == nil || headers.count == 0) {
        return;
    }
    if([NRMAFlags shouldEnableNewEventSystem]){
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        @synchronized (self) {
            for(NSString* key in [self trackedHeaderFields]) {
                NSString* value = headers[key];
                
                if(value != nil) {
                    NSString* normalizedKey = [NRMAHTTPUtilities normalizeApolloHeaders:key];
                    [dict setValue:value forKey:normalizedKey];
                }
            }
        }
        requestData.trackedHeaders = dict;
    } else {
        std::map<std::string, std::string> cDict;
        @synchronized (self) {
            for(NSString* key in [self trackedHeaderFields]) {
                NSString* value = headers[key];
                
                if(value != nil) {
                    NSString* normalizedKey = [NRMAHTTPUtilities normalizeApolloHeaders:key];
                    std::string cValue = std::string(value.UTF8String);
                    std::string cKey = std::string(normalizedKey.UTF8String);
                    cDict[cKey] = cValue;
                }
            }
        }
        NewRelic::NetworkRequestData* wrappedRequestData = [requestData getNetworkRequestData];
        wrappedRequestData->setTrackedHeaders(cDict);
    }
}

@end
