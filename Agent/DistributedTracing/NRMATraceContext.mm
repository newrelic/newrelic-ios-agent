//
//  NRMATraceContext.m
//  Agent
//
//  Created on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "NRMATraceContext.h"

@implementation NRMATraceContext

NSString *INVALID_TRACE_ID = @"00000000000000000000000000000000";
NSString *INVALID_PARENT_ID = @"0000000000000000";
NSString *DT_FIELD_UNUSED = @"";

- (void) setNewRelicDefaults {
    // always overwriten by C++ Payload
    self.accountId = DT_FIELD_UNUSED;
    self.appId = DT_FIELD_UNUSED;
    self.traceId = INVALID_TRACE_ID;
    self.spanId = INVALID_PARENT_ID;
    self.TRACE_FIELD_UNUSED = DT_FIELD_UNUSED;
    self.timestamp = 0;
    self.trustedAccount = NRTraceContext;
}

- (void) setTrustedAccountKey: (AccountType) trustedAccount {
    self.trustedAccount = trustedAccount;
}

- (id) init {
    [self setNewRelicDefaults];
    return self;
}

- (id) initWithPayload: (const std::unique_ptr<NewRelic::Connectivity::Payload>&)payload{
    [self setNewRelicDefaults];

    self.accountId = [NSString stringWithCString:payload->getAccountId().c_str()
                                        encoding:NSUTF8StringEncoding];
    self.appId = [NSString stringWithCString:payload->getAppId().c_str()
                                    encoding:NSUTF8StringEncoding];
    self.traceId = [NSString stringWithCString:payload->getTraceId().c_str()
                                            encoding:NSUTF8StringEncoding];
    self.spanId = [NSString stringWithCString:payload->getId().c_str()
                                     encoding:NSUTF8StringEncoding];
    self.timestamp = payload->getTimestamp();
    
    return self;
}

@end
