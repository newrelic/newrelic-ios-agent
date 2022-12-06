//
//  NRMATraceContext.h
//  Agent
//
//  Created on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Connectivity/Payload.hpp>

typedef enum trustedAccountKeys: NSUInteger {
    NRTraceContext,
    W3CTraceContext
} AccountType;

@interface NRMATraceContext : NSObject

@property (strong) NSString*   accountId;
@property (strong) NSString*   appId;
// Should match parentId
@property (strong) NSString*   spanId;
@property (strong) NSString*   traceId;
@property          long long   timestamp;
@property          AccountType trustedAccount;
// For optional/not supported fields
@property (strong) NSString*   TRACE_FIELD_UNUSED;

- (id) initWithPayload: (const std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (void) setTrustedAccountKey: (AccountType) trustedAccount;

@end
