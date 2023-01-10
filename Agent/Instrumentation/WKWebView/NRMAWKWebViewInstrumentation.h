//
// Created by Bryce Buchanan on 1/4/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "NRMAWebRequestUtil.h"

@interface NRMAWKWebViewInstrumentation : NSObject
+ (void) instrument;
+ (void) deinstrument;
@end


