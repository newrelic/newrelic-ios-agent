//
//  NRMARetryTracker.h
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <Foundation/Foundation.h>

/*
 * This object tracks retries on an object. A counter is incremented when an associated object is passed to
 * "shouldRetryTask:" when the retry limited is reached--defined in the `initWithRetryLimit:`--`shouldRetryTask:`
 * returns NO, otherwise YES.
 * example: if the object is initialized with retries=3 shouldRetryTask: will return YES three times before returning NO
 * Tracking is limited to in memory. Once the object is destructed all tracking is lost.
 * If the object passed to `shouldRetryTask:` is not tracked the method will return NO
 */
@interface NRMARetryTracker : NSObject
- (instancetype) initWithRetryLimit:(unsigned int)retries;
- (void) track:(id<NSCopying>)object;
- (void) untrack:(id<NSCopying>)object;
- (BOOL) shouldRetryTask:(id<NSCopying>)object;
@end
