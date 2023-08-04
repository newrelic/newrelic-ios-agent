//
//  NRMANetworkUtilites.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAPayloadContainer.h"
#import "NRMAPayload.h"

#define NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY               @"newrelic"
#define W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY               @"tracestate"
#define W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY              @"traceparent"

@interface NRMAHTTPUtilities : NSObject
+ (NSMutableURLRequest*) addCrossProcessIdentifier:(NSURLRequest*)request;
+ (NSMutableURLRequest*) makeMutable:(NSURLRequest*)request;
+ (NSMutableURLRequest*) addConnectivityHeaderAndPayload:(NSURLRequest*)request;
+ (NRMAPayloadContainer *)generatePayload;
+ (NRMAPayload *) generateNRMAPayload;
#if USE_INTEGRATED_EVENT_MANAGER
+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithPayload:(NRMAPayload*)payload;
+ (void) attachPayload:(NRMAPayload*)payload to:(id)object;
+ (NRMAPayload*) addConnectivityHeader:(NSMutableURLRequest*)request;
#else
+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithPayload:(NRMAPayloadContainer*)payloadContainer;
+ (void) attachPayload:(NRMAPayloadContainer*)payload to:(id)object;
+ (NRMAPayloadContainer*) addConnectivityHeader:(NSMutableURLRequest*)request;
#endif
@end
