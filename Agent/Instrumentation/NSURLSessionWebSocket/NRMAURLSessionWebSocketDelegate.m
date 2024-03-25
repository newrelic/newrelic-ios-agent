//
//  NRMAURLSessionWebSocketDelegate.m
//  Agent
//
//  Created by Mike Bruin on 7/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "NRMAURLSessionWebSocketDelegate.h"

@implementation NRMAURLSessionWebSocketDelegate
- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([self.realDelegate respondsToSelector:aSelector]){
        return YES;
    }

    return [super respondsToSelector:aSelector];
}

- (BOOL) isKindOfClass:(Class)aClass {
    return self.class == aClass || [super isKindOfClass:aClass] || [self.realDelegate isKindOfClass:aClass];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.realDelegate;
}

@end
