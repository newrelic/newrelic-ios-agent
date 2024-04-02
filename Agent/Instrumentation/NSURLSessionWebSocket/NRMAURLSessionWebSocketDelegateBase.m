//
//  NRMAURLSessionWebSocketDelegateBase.m
//  Agent
//
//  Created by Mike Bruin on 7/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionWebSocketDelegateBase.h"
#import "NRMANetworkFacade.h"
#import <objc/runtime.h>
#import "NRTimer.h"

@class URLSessionWebSocketTask;
@protocol URLSessionWebSocketDelegate;

@implementation NRMAURLSessionWebSocketDelegateBase

- (instancetype) initWithOriginalDelegate:(NSObject<URLSessionWebSocketDelegate>* __nullable __weak)delegate {
    self = [super init];
    if (self) {
        _realDelegate = delegate;
    }
    return self;
}

#pragma mark - WKNavigationDelegate methods

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(NSString *)protocol API_AVAILABLE(ios(13.0))
{
    if ([self.realDelegate respondsToSelector:_cmd]) {
        NSArray* parameters = [NSArray arrayWithObjects:
                              [NSValue valueWithPointer: &(session)],
                              [NSValue valueWithPointer: &(webSocketTask)],
                              [NSValue valueWithPointer: &(protocol)],
                               nil];
        [self invokeMethod:[self.realDelegate methodSignatureForSelector:_cmd] selector:_cmd parameters:parameters];
    }
}

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(NSData *)reason API_AVAILABLE(ios(13.0))
{
    if ([self.realDelegate respondsToSelector:_cmd]) {
        NSArray* parameters = [NSArray arrayWithObjects:
                              [NSValue valueWithPointer: &(session)],
                              [NSValue valueWithPointer: &(webSocketTask)],
                              [NSValue valueWithPointer: &(closeCode)],
                              [NSValue valueWithPointer: &(reason)],
                               nil];
        [self invokeMethod:[self.realDelegate methodSignatureForSelector:_cmd] selector:_cmd parameters:parameters];
    }
}
    
-(void)invokeMethod:(NSMethodSignature*) methodSignature selector:(SEL)selector parameters:(NSArray*)parameters {
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[self.realDelegate methodSignatureForSelector:selector]];
    [inv setSelector:selector];
    [inv setTarget:self.realDelegate];

    for(int i = 0; i < parameters.count; i++) {
        NSValue *value = [parameters objectAtIndex:i];
        [inv setArgument:[value pointerValue] atIndex:i+2];//arguments 0 and 1 are self.realDelegate and _cmd respectively, automatically set by NSInvocation
    }
    
    [inv invoke];
}

@end
