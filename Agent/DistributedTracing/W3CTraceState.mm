//
//  W3CTraceState.mm
//  Agent
//
//  Created on 12/23/20.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "W3CTraceState.h"

@implementation W3CTraceState

+ (NSString *) trustedAccountKeyFor:(NRMATraceContext*) traceContext {
    switch (traceContext.trustedAccount) {
        case NRTraceContext:
            if(traceContext.trustedAccountKeyString){
                return [NSString stringWithFormat:@"%@@nr", traceContext.trustedAccountKeyString];
            } else {
                return @"@nr";
            }
        default:
            return @"";
    }
}

+ (NSString *) getVersion {
    return @"0";
}
+ (NSString *) getParentType {
    return @"2";
}
+ (NSString *) getSampled {
    return @"0";
}
+ (NSString *) getPriority {
    return @"";
}
+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext {
    NSString *formatStr = @"%@=%@-%@-%@-%@-%@-%@-%@-%@-%lld";

    // Do not base64 encode. traceContext.spanId should equal traceparent->parentId.
    NSString *headerString = [NSString stringWithFormat:formatStr,
                              [W3CTraceState trustedAccountKeyFor: traceContext],
                              [W3CTraceState getVersion],
                              [W3CTraceState getParentType],
                              traceContext.accountId,
                              traceContext.appId,
                              traceContext.spanId,
                              traceContext.TRACE_FIELD_UNUSED,
                              [W3CTraceState getSampled],
                              [W3CTraceState getPriority],
                              traceContext.timestamp];
    
    return headerString;
}

@end
