//
//  W3TraceParent.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "NRMATraceContext.h"

@interface W3CTraceParent : NSObject

+ (NSString *) headerFromContext:(NRMATraceContext*) traceContext;

@end
