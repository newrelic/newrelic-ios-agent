//
//  W3CTraceParent.mm
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceParent.h"

@implementation W3CTraceParent

+ (NSString *) getVersion {
    return @"00";
}
+ (NSString *) getFlags {
    return @"00";
}

+ (NSString *) headerFromContext:(TraceContext*) traceContext {
    NSString *formatStr = @"%@-%@-%@-%@";

    // do not base64 encode
    NSString *headerString = [NSString stringWithFormat:formatStr,
                              [W3CTraceParent getVersion],
                              traceContext.traceId,
                              traceContext.spanId,
                              [W3CTraceParent getFlags]];
    
    return headerString;
}

@end
