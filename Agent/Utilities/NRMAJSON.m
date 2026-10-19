//
//  NRMAJSON.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 4/8/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAJSON.h"
#import "NRLogger.h"
#import "NRMAExceptionHandler.h"
#import "NRMAMethodSwizzling.h"
#import <objc/runtime.h>

@implementation NRMAJSON

+ (NSData*) dataWithJSONABLEObject:(id<NRMAJSONABLE>)obj options:(NSJSONWritingOptions)opt error:(NSError *__autoreleasing *)error {
    if (![obj conformsToProtocol:@protocol(NRMAJSONABLE)]) {
        NRLOG_AGENT_ERROR(@"object passed to NRMAJSON not jsonable.");
        (*error) = [NSError errorWithDomain:@"InvalidFirstParameter" code:-1 userInfo:nil];
        return nil;
    }
    id jsonObj = nil;
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
        #endif
        jsonObj = [obj JSONObject];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        NRLOG_AGENT_ERROR(@"object passed to NRJSON failed to convert to json.");
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([obj class])
                                selector:@"JSONObject"];
        if (error != nil) {
            *error = [NSError errorWithDomain:@"Could not convert obj to JSON"
                                           code:-2
                                       userInfo:nil];
        }
        return nil;
    }
#endif
    return [NRMAJSON dataWithJSONObject:jsonObj options:opt error:error];
}

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError * __autoreleasing *)error {
    Class clazz = objc_getClass("NSJSONSerialization");
    if (clazz) {
        if (![clazz isValidJSONObject:obj]) {
            if (error != nil) {
                *error = [NSError errorWithDomain:@"json.invalid.object" code:-1 userInfo:nil];
            }
            return nil;
        }
        // Call through the agent's own stored-original implementation, not
        // +dataWithJSONObject:options:error: directly -- NRMAMethodProfiler
        // instruments that selector for app-interaction tracing, and this
        // internal usage (NRLogger serializes a JSON dict for every log
        // message via this method) must not be mistaken for app activity or
        // re-enter that tracing on every log line.
        SEL selector = NRMAUninstrumentedSelector(clazz, @selector(dataWithJSONObject:options:error:));
        Method m = class_getClassMethod(clazz, selector);
        NSData *(*func)(id, SEL, id, NSJSONWritingOptions, NSError * __autoreleasing *) = (void *)method_getImplementation(m);
        return func(clazz, selector, obj, opt, error);
    }
    if (error)
        *error = [NSError errorWithDomain:@"json.not.available" code:-1 userInfo:nil];
    return nil;
}

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError * __autoreleasing*)error {
    Class clazz = objc_getClass("NSJSONSerialization");
    if (clazz) {
        // See -dataWithJSONObject:options:error: above: bypass the agent's own
        // app-interaction tracing instrumentation for this internal usage.
        SEL selector = NRMAUninstrumentedSelector(clazz, @selector(JSONObjectWithData:options:error:));
        Method m = class_getClassMethod(clazz, selector);
        id (*func)(id, SEL, NSData *, NSJSONReadingOptions, NSError * __autoreleasing *) = (void *)method_getImplementation(m);
        return func(clazz, selector, data, opt, error);
    }
    if (error)
        *error = [NSError errorWithDomain:@"json.not.available" code:-1 userInfo:nil];
    return nil;
}

@end
