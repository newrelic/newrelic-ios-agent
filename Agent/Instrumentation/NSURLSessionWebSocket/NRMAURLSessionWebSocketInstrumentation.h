//
//  NRMAURLSessionWebSocketInstrumentation.h
//  Agent
//
//  Created by Mike Bruin on 7/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>


@interface NRMAURLSessionWebSocketInstrumentation : NSObject
+ (void) instrument;
+ (void) deinstrument;
@end
