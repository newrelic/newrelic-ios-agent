//
//  NRMAURLSessionTaskOverride.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 3/20/14.
//  Copyright (c) 2014 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRTimer.h"
void NRMAOverride__resume(id self, SEL _cmd);
void NRMAOverride__urlSessionTask_SetState(NSURLSessionTask *sessionTask, SEL _cmd, NSURLSessionTaskState *newState);

@interface NRMAURLSessionTaskOverride : NSObject

+ (void) deinstrument;
+ (void) instrumentConcreteClass:(Class)clazz;
@end

