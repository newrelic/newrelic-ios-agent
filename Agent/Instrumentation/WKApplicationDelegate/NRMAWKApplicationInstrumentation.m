//
//  NRMAWKApplicationInstrumentation.m
//  Agent-watchOS
//
//  Created by Mike Bruin on 5/8/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAWKApplicationInstrumentation.h"
#import "NRMAWKApplicationDelegate.h"
#import <WatchKit/WatchKit.h>
#import "NRMAMethodSwizzling.h"
#import "NewRelicAgentInternal.h"

static id NRMAOverride__delegate(id self, SEL _cmd);
static id NRMAOverride__init(id self, SEL _cmd);

// IMPORTANT: calling this method seems to increment the retain count by 1.
//ensure that this method is wrapped inside an autorelease pool whenever used.
id (*NRMA__WKApplication_Delegate)(id self, SEL _cmd);
id (*NRMA__WKApplication_init)(id self, SEL _cmd);

//NOTE: this files has ARC disabled.

@implementation NRMAWKApplicationInstrumentation

+ (void) instrument {
    Class clazz = objc_getClass("WKApplication");
    if (clazz) {
        NRMA__WKApplication_Delegate = NRMASwapImplementations(clazz, @selector(delegate), (IMP)NRMAOverride__delegate);
    }
}

+ (void) deinstrument {
    Class clazz = objc_getClass("WKApplication");
    if (clazz) {
        SEL delegateSelector = @selector(delegate);
        method_setImplementation(class_getInstanceMethod(clazz, delegateSelector),(IMP)NRMA__WKApplication_Delegate);
    }
}

@end

static id NRMAOverride__delegate(id self, SEL _cmd) {
    @autoreleasepool {
        id delegate = NRMA__WKApplication_Delegate(self,_cmd);
        [NewRelicAgentInternal checkApplicationState:[WKApplication sharedApplication].applicationState];
        if ([delegate isKindOfClass:[NRMAWKApplicationDelegate class]]) {
            return ((NRMAWKApplicationDelegate*)delegate).realDelegate;
        }
        return delegate;
    }
}

/*static void NRMAOverride__setDelegate(id self, SEL _cmd, id delegate) {
    @autoreleasepool {
        id lastDelegate = NRMA__WKApplication_Delegate(self,_cmd);
        if ([delegate isKindOfClass:[NRMAWKApplicationDelegate class]]) {
            ((NRMAWKApplicationDelegate*)delegate).realDelegate = delegate;
        }
        id value = [[NRMAWKApplicationDelegate alloc] initWithOriginalDelegate:delegate];
        NRMA__WKApplication_setDelegate(self, _cmd, value);

        if (lastDelegate != nil && lastDelegate != delegate) {
            //don't try to release nil
            //don't release the last delegate if the the same object is being passed as the incoming delegate.
            [lastDelegate release];
        }
    }
}*/
