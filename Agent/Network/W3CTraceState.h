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
#import "Payload.hpp"
#import "W3CTraceContext.h"

@interface W3CTraceState : NSObject <W3TraceContext>

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;

- (NSString *) createHeader;
- (NSString *) createHeaderFor:(AccountType) trustedAccount;
+ (NSString *) headerFromContext:(TraceContext*) traceContext;

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
