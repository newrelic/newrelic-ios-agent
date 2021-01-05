//
//  W3CTraceContext.h
//  Agent
//
//  Created by Matt Aken on 12/23/20.
//  Copyright © 2020 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Payload.hpp"

@protocol W3TraceContext <NSObject>

- (id) initWithPayload: (std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
- (NSString *) createHeader;

@end
