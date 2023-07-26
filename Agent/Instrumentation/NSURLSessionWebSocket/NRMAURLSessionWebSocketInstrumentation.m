//
//  NRMAURLSessionWebSocketInstrumentation.m
//  Agent
//
//  Created by Mike Bruin on 7/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionWebSocketInstrumentation.h"
#import "NRMAURLSessionWebSocketDelegate.h"
#import "NRMAMethodSwizzling.h"
#import <UIKit/UIKit.h>


//NOTE: this files has ARC disabled.

static id NRMAOverride__webSocketTaskWithURL(id self, SEL _cmd, NSURL* url);
static id NRMAOverride__webSocketTaskWithURL_protocols(id self, SEL _cmd, NSURL* url, NSArray<NSString *>* protocols);
static id NRMAOverride__webSocketTaskWithRequest(id self, SEL _cmd, NSURLRequest* request);

static id NRMAOverride__delegate(id self, SEL _cmd);
static void NRMAOverride__setDelegate(id self, SEL _cmd, id delegate);
static void NRMAOverride__dealloc(id self, SEL _cmd);

API_AVAILABLE(ios(13.0))
void NRMAOverride__webSocketTaskSendMessage(id self, SEL _cmd, NSURLSessionWebSocketMessage* message, void(^completionHandler)(NSError *error));
API_AVAILABLE(ios(13.0))
void NRMAOverride__webSocketTaskReceiveMessage(id self, SEL _cmd, void(^completionHandler)(NSURLSessionWebSocketMessage* message, NSError *error));
API_AVAILABLE(ios(13.0))
void NRMAOverride__webSocketTaskCancelWithCloseCode(id self, SEL _cmd, NSURLSessionWebSocketCloseCode closeCode, NSData* reason);

id (*NRMA__webSocketTaskWithURL)(id self, SEL _cmd, NSURL* url);
id (*NRMA__webSocketTaskWithURL_protocols)(id self, SEL _cmd, NSURL* url, NSArray<NSString *>* protocols);
id (*NRMA__webSocketTaskWithRequest)(id self, SEL _cmd, NSURLRequest* request);

API_AVAILABLE(ios(13.0))
void (*NRMA__webSocketTaskSendMessage)(id self, SEL _cmd, NSURLSessionWebSocketMessage* message, void(^completionHandler)(NSError *error));
API_AVAILABLE(ios(13.0))
void (*NRMA__webSocketTaskReceiveMessage)(id self, SEL _cmd, void(^completionHandler)(NSURLSessionWebSocketMessage* message, NSError *error));
API_AVAILABLE(ios(13.0))
void (*NRMA__webSocketTaskCancelWithCloseCode)(id self, SEL _cmd, NSURLSessionWebSocketCloseCode closeCode, NSData* reason);


// IMPORTANT: calling this method seems to increment the retain count by 1.
//ensure that this method is wrapped inside an autorelease pool whenever used.
id (*NRMA__WebSocketTask_Delegate)(id self, SEL _cmd);
void (*NRMA__WebSocketTask_setDelegate)(id self, SEL _cmd, id delegate);
void (*NRMA__WebSocketTask_dealloc)(id self, SEL _cmd);


@implementation NRMAURLSessionWebSocketInstrumentation

+ (void) instrument {
    
    id clazz = objc_getClass("NSURLSessionWebSocketTask");
    if (clazz) {
        if (@available(iOS 13, *)) {
            NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            id obj = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://demo.com"]];
            id concreteClass = [obj class];
            clazz = concreteClass;
        }
        
        NRMA__WebSocketTask_Delegate = NRMASwapImplementations(clazz, @selector(delegate), (IMP)NRMAOverride__delegate);

        NRMA__WebSocketTask_setDelegate = NRMASwapImplementations(clazz, @selector(setDelegate:), (IMP)NRMAOverride__setDelegate);

        NRMA__WebSocketTask_dealloc = NRMASwapImplementations(clazz, @selector(dealloc), (IMP)NRMAOverride__dealloc);
        
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            NRMA__webSocketTaskSendMessage = NRMASwapImplementations(clazz, @selector(sendMessage:completionHandler:), (IMP)NRMAOverride__webSocketTaskSendMessage);
            NRMA__webSocketTaskReceiveMessage = NRMASwapImplementations(clazz, @selector(receiveMessageWithCompletionHandler:), (IMP)NRMAOverride__webSocketTaskReceiveMessage);
            NRMA__webSocketTaskCancelWithCloseCode = NRMASwapImplementations(clazz, @selector(cancelWithCloseCode:reason:), (IMP)NRMAOverride__webSocketTaskCancelWithCloseCode);
        }
    }
    
    clazz = objc_getClass("NSURLSession");
    if (clazz) {
        SEL webSocketTaskWithURLSelector = @selector(webSocketTaskWithURL:);
        Method webSocketTaskWithURLMethod = class_getInstanceMethod(clazz, webSocketTaskWithURLSelector);
        NRMA__webSocketTaskWithURL = (id(*)(id,SEL,NSURL*))class_replaceMethod(clazz,
                                                                               webSocketTaskWithURLSelector,
                                                                               (IMP)NRMAOverride__webSocketTaskWithURL,
                                                                               method_getTypeEncoding(webSocketTaskWithURLMethod));
        
        SEL webSocketTaskWithURLProtocolsSelector = @selector(webSocketTaskWithURL:protocols:);
        Method webSocketTaskWithURLProtocolsMethod = class_getInstanceMethod(clazz, webSocketTaskWithURLProtocolsSelector);
        NRMA__webSocketTaskWithURL_protocols = (id(*)(id,SEL,NSURL*,NSArray<NSString *>*))class_replaceMethod(clazz,
                                                                                                              webSocketTaskWithURLProtocolsSelector,
                                                                                                              (IMP)NRMAOverride__webSocketTaskWithURL_protocols,
                                                                                                              method_getTypeEncoding(webSocketTaskWithURLProtocolsMethod));
        
        SEL webSocketTaskWithRequestSelector = @selector(webSocketTaskWithRequest:);
        Method webSocketTaskWithRequestMethod = class_getInstanceMethod(clazz, webSocketTaskWithRequestSelector);
        NRMA__webSocketTaskWithRequest = (id(*)(id,SEL,NSURLRequest*))class_replaceMethod(clazz,
                                                                                          webSocketTaskWithRequestSelector,
                                                                                          (IMP)NRMAOverride__webSocketTaskWithRequest,
                                                                                          method_getTypeEncoding(webSocketTaskWithRequestMethod));
    }
}

+ (void) deinstrument {
    Class clazz = objc_getClass("NSURLSessionWebSocketTask");
    if (clazz) {
        SEL webSocketTaskWithURLSelector = @selector(webSocketTaskWithURL:);
        method_setImplementation(class_getInstanceMethod(clazz, webSocketTaskWithURLSelector),(IMP)NRMA__webSocketTaskWithURL);
        
        SEL webSocketTaskWithURLProtocolSelector = @selector(webSocketTaskWithURL:protocols:);
        method_setImplementation(class_getInstanceMethod(clazz, webSocketTaskWithURLProtocolSelector),(IMP)NRMA__webSocketTaskWithURL_protocols);
        
        SEL webSocketTaskWithRequestSelector = @selector(webSocketTaskWithRequest:);
        method_setImplementation(class_getInstanceMethod(clazz, webSocketTaskWithRequestSelector),(IMP)NRMA__webSocketTaskWithRequest);
    }
    
    clazz = objc_getClass("NSURLSessionWebSocketTask");
    if (clazz) {
        SEL delegateSelector = @selector(delegate);
        method_setImplementation(class_getInstanceMethod(clazz, delegateSelector),(IMP)NRMA__WebSocketTask_Delegate);
        
        SEL setDelegateSelector = @selector(setDelegate:);
        method_setImplementation(class_getInstanceMethod(clazz, setDelegateSelector), (IMP)NRMA__WebSocketTask_setDelegate);
        
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            SEL sendMessageSelector = @selector(sendMessage:completionHandler:);
            method_setImplementation(class_getInstanceMethod(clazz, sendMessageSelector), (IMP)NRMA__webSocketTaskSendMessage);
            SEL receiveMessageSelector = @selector(receiveMessageWithCompletionHandler:);
            method_setImplementation(class_getInstanceMethod(clazz, receiveMessageSelector), (IMP)NRMA__webSocketTaskReceiveMessage);
            SEL cancelSelector = @selector(cancelWithCloseCode:reason:);
            method_setImplementation(class_getInstanceMethod(clazz, cancelSelector), (IMP)NRMA__webSocketTaskCancelWithCloseCode);
        }
    }
}

@end


void NRMAOverride__dealloc(id self, SEL _cmd) {
    @autoreleasepool {
        [NRMA__WebSocketTask_Delegate(self, @selector(delegate)) release];
        NRMA__WebSocketTask_dealloc(self, _cmd);
    }
}

static id NRMAOverride__delegate(id self, SEL _cmd) {
    @autoreleasepool {
        
    id delegate = NRMA__WebSocketTask_Delegate(self,_cmd);
    if ([delegate isKindOfClass:[NRMAURLSessionWebSocketDelegate class]]) {
        return ((NRMAURLSessionWebSocketDelegate*)delegate).realDelegate;
    }
    return delegate;
    }
}

static void NRMAOverride__setDelegate(id self, SEL _cmd, id delegate) {
    @autoreleasepool {
        id lastDelegate = NRMA__WebSocketTask_Delegate(self,_cmd);
        if ([delegate isKindOfClass:[NRMAURLSessionWebSocketDelegate class]]) {
            ((NRMAURLSessionWebSocketDelegate*)delegate).realDelegate = delegate;
        }
        id value = [[NRMAURLSessionWebSocketDelegate alloc] initWithOriginalDelegate:delegate];
        NRMA__WebSocketTask_setDelegate(self, _cmd, value);
        
        if (lastDelegate != nil && lastDelegate != delegate) {
            //don't try to release nil
            //don't release the last delegate if the the same object is being passed as the incoming delegate.
            [lastDelegate release];
        }
    }
}

id NRMAOverride__webSocketTaskWithURL(id self, SEL _cmd, NSURL* url) {
     id result = NRMA__webSocketTaskWithURL(self, _cmd, url);
    NRMA__WebSocketTask_setDelegate(result, _cmd, [[NRMAURLSessionWebSocketDelegate alloc] initWithOriginalDelegate:nil]);
    return result;
}

id NRMAOverride__webSocketTaskWithURL_protocols(id self, SEL _cmd, NSURL* url, NSArray<NSString *>* protocols) {
    id result = NRMA__webSocketTaskWithURL_protocols(self, _cmd, url, protocols);
    NRMA__WebSocketTask_setDelegate(result, _cmd, [[NRMAURLSessionWebSocketDelegate alloc] initWithOriginalDelegate:nil]);
    return result;
}

id NRMAOverride__webSocketTaskWithRequest(id self, SEL _cmd, NSURLRequest* request) {
    id result = NRMA__webSocketTaskWithRequest(self, _cmd, request);
    NRMA__WebSocketTask_setDelegate(result, _cmd, [[NRMAURLSessionWebSocketDelegate alloc] initWithOriginalDelegate:nil]);
    return result;
}

void NRMAOverride__webSocketTaskSendMessage(id self, SEL _cmd, NSURLSessionWebSocketMessage* message, void(^completionHandler)(NSError *error))
{
    return NRMA__webSocketTaskSendMessage(self, _cmd, message, completionHandler);
}

void NRMAOverride__webSocketTaskReceiveMessage(id self, SEL _cmd, void(^completionHandler)(NSURLSessionWebSocketMessage* message, NSError *error))
{
    return NRMA__webSocketTaskReceiveMessage(self, _cmd, completionHandler);
}

void NRMAOverride__webSocketTaskCancelWithCloseCode(id self, SEL _cmd, NSURLSessionWebSocketCloseCode closeCode, NSData* reason)
{
    return NRMA__webSocketTaskCancelWithCloseCode(self, _cmd, closeCode, reason);
}


