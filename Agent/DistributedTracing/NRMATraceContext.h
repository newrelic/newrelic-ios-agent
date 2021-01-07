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
@property (strong) NSString*   spanId; // should match parentId
@property (strong) NSString*   traceId;
@property          long long   timestamp;
@property          AccountType trustedAccount;

@property (strong) NSString*   TRACE_FIELD_UNUSED; // for optional/not supported fields

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (void) setTrustedAccountKey: (AccountType) trustedAccount;

@end
