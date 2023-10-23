//
//  NRMANetworkUtilites.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAPayloadContainer.h"
#import "NRMANetworkRequestData.h"

#define NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY               @"newrelic"
#define W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY               @"tracestate"
#define W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY              @"traceparent"

NS_ASSUME_NONNULL_BEGIN
@interface NRMAHTTPUtilities : NSObject
+ (NSMutableURLRequest*) addCrossProcessIdentifier:(NSURLRequest*)request;
+ (NSMutableURLRequest*) makeMutable:(NSURLRequest*)request;
+ (NSMutableURLRequest*) addConnectivityHeaderAndPayload:(NSURLRequest*)request;
+ (NRMAPayloadContainer*) addConnectivityHeader:(NSMutableURLRequest*)request;
+ (void) attachPayload:(NRMAPayloadContainer*)payload to:(id)object;
+ (NRMAPayloadContainer *)generatePayload;
+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithPayload:(NRMAPayloadContainer*)payloadContainer;
+ (NSArray*) trackedHeaderFields;
+ (void) addHTTPHeaderTrackingFor:(NSArray *)headers;
+ (void) addGraphQLHeaders:(NSDictionary *)headers to:(NRMANetworkRequestData*)requestData;
@end
NS_ASSUME_NONNULL_END
