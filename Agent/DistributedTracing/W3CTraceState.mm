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
//+ (NSString *) getSampled {
//    return @"0";
//}
+ (NSString *) getPriority {
    return @"";
}
+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext {
                          //1  2  3  4  5  6  7   9  10
    NSString *formatStr = @"%@=%@-%@-%@-%@-%@-%@-%@-%lld";

    // Do not base64 encode. traceContext.spanId should equal traceparent->parentId.
    NSString *headerString = [NSString stringWithFormat:formatStr,
                              [W3CTraceState trustedAccountKeyFor: traceContext], // 1
                              [W3CTraceState getVersion],                         // 2
                              [W3CTraceState getParentType],                      // 3
                              traceContext.accountId,                             // 4
                              traceContext.appId,                                 // 5
                              traceContext.spanId,                                // 6
                              traceContext.TRACE_FIELD_UNUSED,                    // 7
                              // Note: We used to pass 0 as the sampled flag but the Language agent teams requested this change.
//                              [W3CTraceState getSampled],                         // 8
                              [W3CTraceState getPriority],                        // 9
                              traceContext.timestamp];                            // 10

    return headerString;
}

@end
