//
//  W3TraceState.h
//  Agent
//
//  Implementation of https://w3c.github.io/trace-context/#tracestate-header
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <Connectivity/Payload.hpp>
#import "NRMATraceContext.h"

@interface W3CTraceState : NSObject

+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext;

@property          int        version;
@property          int        parentType;
@property (strong) NSString*  accountId;
@property (strong) NSString*  appId;
@property (strong) NSString*  spanId;
@property (strong) NSString*  transactionId;
@property          int        sampled;
@property (strong) NSString*  priority;
@property          long long  timestamp;

@end
