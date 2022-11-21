//
//  NRMAJSON.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 4/8/13.
//  Copyright (c) 2013 New Relic. All rights reserved.
//

#import "NRMAJSON.h"
#import "NRLogger.h"
#import "NRMAExceptionHandler.h"
#import <objc/runtime.h>

@implementation NRMAJSON

+ (NSData*) dataWithJSONABLEObject:(id<NRMAJSONABLE>)obj options:(NSJSONWritingOptions)opt error:(NSError *__autoreleasing *)error {
    if (![obj conformsToProtocol:@protocol(NRMAJSONABLE)]) {
        NRLOG_ERROR(@"object passed to NRMAJSON not jsonable.");
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
        NRLOG_ERROR(@"object passed to NRJSON failed to convert to json.");
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
    id clazz = objc_getClass("NSJSONSerialization");
    if (clazz) {
        if (![clazz isValidJSONObject:obj]) {
            if (error != nil) {
                *error = [NSError errorWithDomain:@"json.invalid.object" code:-1 userInfo:nil];
            }
            return nil;
        }
        return [clazz dataWithJSONObject:obj options:opt error:error];
    }
    if (error)
        *error = [NSError errorWithDomain:@"json.not.available" code:-1 userInfo:nil];
    return nil;
}

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError * __autoreleasing*)error {
    id clazz = objc_getClass("NSJSONSerialization");
    if (clazz) {
        return [clazz JSONObjectWithData:data options:opt error:error];
    }
    if (error)
        *error = [NSError errorWithDomain:@"json.not.available" code:-1 userInfo:nil];
    return nil;
}

@end
