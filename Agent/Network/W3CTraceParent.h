//
//  W3TraceParent.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import "W3CTraceContext.h"

@interface W3CTraceParent : NSObject <W3TraceContext>

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (NSString *) createHeader;

@property(nonatomic)         int        version;
@property(nonatomic, strong) NSString*  traceId;
@property(nonatomic, strong) NSString*  parentId;
@property(nonatomic, strong) NSString*  flags;

@end
