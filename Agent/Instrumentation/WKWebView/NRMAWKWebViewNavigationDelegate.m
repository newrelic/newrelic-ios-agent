//
//  NRMAWKWebViewNavigationDelegate.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/5/17.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "NRMAWKWebViewNavigationDelegate.h"

@implementation NRMAWKWebViewNavigationDelegate
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
    // realDelegate is held weakly. WebKit caches the result of respondsToSelector:
    // at navigation-delegate-assignment time, so it can later send us a selector that
    // only the real delegate implements (e.g. webViewWebContentProcessDidTerminate:,
    // which fires when a backgrounded web view's content process is reclaimed) after
    // that real delegate has been deallocated. Only fast-forward when the real delegate
    // is still alive and actually implements the selector; otherwise return nil so the
    // message drops into the full forwarding machinery below and is absorbed rather than
    // falling through to doesNotRecognizeSelector: and crashing the host app.
    NSObject* delegate = self.realDelegate;
    if ([delegate respondsToSelector:aSelector]) {
        return delegate;
    }
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature* signature = [super methodSignatureForSelector:aSelector];
    if (signature) {
        return signature;
    }

    NSObject* delegate = self.realDelegate;
    if ([delegate respondsToSelector:aSelector]) {
        return [delegate methodSignatureForSelector:aSelector];
    }

    // The real delegate was deallocated after WebKit cached respondsToSelector: == YES.
    // Return a benign void signature so the runtime routes the call to forwardInvocation:
    // (where it is dropped) instead of to doesNotRecognizeSelector: (which would throw).
    return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSObject* delegate = self.realDelegate;
    if ([delegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:delegate];
    }
    // Otherwise the real delegate is gone; silently drop the message instead of crashing.
}

@end
