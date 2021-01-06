//
//  W3CTraceContext.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Payload.hpp"

typedef enum trustedAccountKeys: NSUInteger {
    NRTraceContext,
    W3CTraceContext
} AccountType;

@interface TraceContext

@property (strong) NSString*   accountId; // from payload
@property (strong) NSString*   appId; // from payload
@property (strong) NSString*   spanId; // should match parentId
@property (strong) NSString*   traceId; // from payload
@property (strong) NSString*   transactionId; // from payload
@property          long long   timestamp; // from payload
@property          AccountType trustedAccount;

- (id) initFromPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (void) setTrustedAccountKey: (AccountType) trustedAccount;

@end
