//
//  NRMAWKApplicationInstrumentation.h
//  Agent
//
//  Created by Mike Bruin on 5/8/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <objc/runtime.h>

@interface NRMAWKApplicationInstrumentation : NSObject
+ (void) instrument;
+ (void) deinstrument;
@end
