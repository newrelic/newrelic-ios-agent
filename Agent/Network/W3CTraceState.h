//
//  W3TraceState.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceContext.h"

@interface W3CTraceState : NSObject <W3TraceContext>

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (NSString *) createHeader;

@property(nonatomic)         int        version;
@property(nonatomic)         int        parentType;
@property(nonatomic, strong) NSString*  accountId;
@property(nonatomic, strong) NSString*  appId;
@property(nonatomic, strong) NSString*  spanId;
@property(nonatomic, strong) NSString*  transactionId;
@property(nonatomic)         int        sampled;
@property(nonatomic)         float      priority;
@property(nonatomic)         long long  timestamp;

@end
