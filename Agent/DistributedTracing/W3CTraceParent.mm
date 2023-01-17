//
//  W3CTraceParent.mm
//  Agent
//
//  Created on 12/23/20.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "W3CTraceParent.h"

@implementation W3CTraceParent

+ (NSString *) getVersion {
    return @"00";
}
+ (NSString *) getFlags {
    return @"00";
}
+ (NSString *) getParentId {
    return @"";
}
+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext {
    NSString *formatStr = @"%@-%@-%@-%@";

    NSString *headerString = [NSString stringWithFormat:formatStr,
                              [W3CTraceParent getVersion],
                              traceContext.traceId,
                              traceContext.spanId,
                              [W3CTraceParent getFlags]];
    return headerString;
}

@end
