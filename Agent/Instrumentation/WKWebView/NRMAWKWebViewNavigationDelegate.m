//
//  NRMAWKWebViewNavigationDelegate.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/5/17.
//  Copyright © 2017 New Relic. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "NRMAWKWebViewNavigationDelegate.h"
#import "NRLogger.h"

@implementation NRMAWKWebViewNavigationDelegate
- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([self.realDelegate respondsToSelector:aSelector]){
        const char* methodName = sel_getName(aSelector);
        NSString *sMethodName = [NSString stringWithUTF8String:methodName];
        NSString *res = [NSString stringWithFormat:@"NRMADISNEY::respondsToSelector NRMAWKWebViewNavigationDelegate<%p> responds to %@", self, sMethodName];
        NRLOG_VERBOSE(@"%@", res);
        NSString *res1 = [NSString stringWithFormat:@"NRMADISNEY::respondsToSelector realDelegate = %p (this is customer's WKNavigationDelegate)", self.realDelegate];
        NRLOG_VERBOSE(@"%@", res1);
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
