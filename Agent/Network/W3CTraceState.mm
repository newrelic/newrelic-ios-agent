//
//  W3CTraceState.mm
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceState.h"

@implementation W3CTraceState

typedef enum trustedAccountKeys: NSUInteger { NRTraceContext, W3CTraceContext } AccountType;


- (NSString *) trustedAccountKeyFor:(AccountType) trustedAccount {
    switch (trustedAccount) {
        case NRTraceContext:
            return @"@nr";
        default:
            return @"";
    }
}

- (NSString *) createHeader {
    NSString *formatStr = @"%@=%1d-%1d-%@-%@-%@-%@-%1d-%.6f-%lld"; // "%s-%s-%s-%s";

    // do not base64 encode
    NSString *headerString = [NSString stringWithFormat:formatStr,
                              [self trustedAccountKeyFor: NRTraceContext],
                              _version,
                              _parentType,
                              _accountId,
                              _appId,
                              _spanId,
                              _transactionId,
                              _sampled,
                              _priority,
                              _timestamp];
    
    return headerString;
}

- (NSString *) invalidParentId {
    return @"0000000000000000";
}

- (void) setNewRelicDefaults {
    _version = 0;
    _parentType = 2;
    _accountId = @"000000";
    _appId = @"00000000000";
    _spanId = @"00000000000";
    _transactionId = @"0000";
    _sampled = 0;
    _priority = 0.0;
    _timestamp = 0;
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
    self.spanId = [NSString stringWithCString:payload->getTraceId().c_str()
                                     encoding:NSUTF8StringEncoding];
    self.transactionId = [NSString stringWithCString:payload->getTraceId().c_str()
                                            encoding:NSUTF8StringEncoding];
    self.timestamp = payload->getTimestamp();
    return self;
}
@end
