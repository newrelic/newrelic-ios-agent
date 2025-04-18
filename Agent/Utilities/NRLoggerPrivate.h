//
//  NRLoggerPrivate.h
//  Agent
//
//  Created by Mike Bruin on 4/17/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRLogger.h"

@interface NRLogger ()

+ (void)agentLogInfo:(NSString*) message;

+ (void)agentLogWarning:(NSString*) message;

+ (void)agentLogError:(NSString*) message;

+ (void)agentLogAudit:(NSString*) message;

+ (void)agentLogVerbose:(NSString*) message;

+ (void)agentLogDebug:(NSString*) message;

@end

