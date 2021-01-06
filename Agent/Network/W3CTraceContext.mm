//
//  W3CTraceContext.m
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceContext.h"

@implementation TraceContext

- (void) setNewRelicDefaults {
    self.spanId = @"XXXXXXXX";
}

- (void) setTrustedAccountKey: (AccountType) trustedAccount {
    self.trustedAccount = trustedAccount;
    self.transactionId = @"";
}

- (id) init {
    [self setNewRelicDefaults];
    return self;
}

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload{
    [self setNewRelicDefaults];

    self.accountId = [NSString stringWithCString:payload->getAccountId().c_str()
                               encoding:NSUTF8StringEncoding];
    self.appId = [NSString stringWithCString:payload->getAppId().c_str()
                                    encoding:NSUTF8StringEncoding];
    self.traceId = [NSString stringWithCString:payload->getTraceId().c_str()
                                            encoding:NSUTF8StringEncoding];
    self.timestamp = payload->getTimestamp();
    
    return self;
}

@end
