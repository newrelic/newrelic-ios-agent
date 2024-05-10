//
//  NRMAWKApplicationDelegate.m
//  Agent-watchOS
//
//  Created by Mike Bruin on 5/8/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAWKApplicationDelegate.h"

@implementation NRMAWKApplicationDelegate
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
