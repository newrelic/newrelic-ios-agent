//
//  W3TraceParent.h
//  Agent
//
//  Created on 12/23/20.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATraceContext.h"

@interface W3CTraceParent : NSObject

+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext;

@end
