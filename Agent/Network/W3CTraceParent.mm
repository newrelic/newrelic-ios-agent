//
//  W3CTraceParent.mm
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceParent.h"

@implementation W3CTraceParent

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
    NSString *formatStr = @"%2d-%@-%@-%@";

    // do not base64 encode
    NSString *headerString = [NSString stringWithFormat:formatStr,
                              _version,
                              _traceId,
                              _parentId,
                              _flags];
    
    return headerString;
}

- (NSString *) invalidParentId {
    return @"0000000000000000";
}

- (void) setNewRelicDefaults {
    _version = 0;
    _parentId = [self invalidParentId];
    _flags = @"00";
}
- (id) init {
    [self setNewRelicDefaults];
    return self;
}

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload{
    [self setNewRelicDefaults];

    self.parentId = [NSString stringWithCString:payload->getParentId().c_str()
                                     encoding:NSUTF8StringEncoding];
    self.traceId = [NSString stringWithCString:payload->getTraceId().c_str()
                                            encoding:NSUTF8StringEncoding];
    return self;
}
@end
