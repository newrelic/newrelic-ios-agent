//
//  NRMAUIImageOverride.h
//  Agent
//
//  Created by Mike Bruin on 1/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NRMAUIImageOverride : NSObject

+ (void)beginInstrumentation;
+ (void)deinstrument;
+ (void)registerURL:(NSURL*)url forData:(NSData*)data;

@end
