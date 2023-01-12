//
//  NRMATraceMachineAgentUserInterface.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 7/9/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMATraceController.h"


@interface NRMATraceMachineAgentUserInterface : NRMATraceController

+ (NSString*) startCustomActivity:(NSString*)named;

+ (void) stopCustomActivity:(NSString*)activityIdentifier;

@end
