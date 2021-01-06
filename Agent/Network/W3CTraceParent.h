//
//  W3TraceParent.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceContext.h"

@interface W3CTraceParent

+ (NSString *) headerFromContext:(TraceContext*) traceContext;

@end
