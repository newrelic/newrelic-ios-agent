//
//  NSObject+NRMAAssociatedObject.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAActingClassUtils.h"
#import "NRMAClassDataContainer.h"
#import <objc/runtime.h>
#import <pthread.h>

static const char key;
static const char depthKey;


void NRMA_pushActingClass(id self, NSString* selector, Class cls)
{
    NSMutableArray* actingClassArray =  NRMA_actingClassArray(self,selector);

    @try {
        [actingClassArray  addObject:[[NRMAClassDataContainer alloc] initWithCls:cls className:NSStringFromClass(cls)]];
    }
    @catch (NSException *exception) {
        if (cls == nil) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"cannot push nil value"
                                         userInfo:nil];
        } else {
            @throw exception;
        }
    }
}

Class NRMA_popActingClass(id self,NSString* selector)
{
    NSMutableArray* actingClassArray = NRMA_actingClassArray(self,selector);
    Class cls;
    cls = ((NRMAClassDataContainer*)[actingClassArray lastObject]).storedClass;
    if (cls != nil) {
        [actingClassArray removeLastObject];
    }
    return cls;
}

Class NRMA_actingClass(id self,NSString* selector)
{
    Class cls = ((NRMAClassDataContainer*)[NRMA_actingClassArray(self,selector) lastObject]).storedClass;
    if (cls == nil) {
        cls = [self class];
    }
    return cls;
}


static NSString* __NRMAActingClassLock = @"NRMAActingClassLock";
NSMutableArray* NRMA_actingClassArray(id self, NSString* selector)
{
    if (self == nil) {
        return nil;
    }

    NSMutableDictionary*  actingClassThreadsDict = nil;
    @synchronized(__NRMAActingClassLock) {
            actingClassThreadsDict = objc_getAssociatedObject(self, &key);

        if (actingClassThreadsDict == nil) {
            actingClassThreadsDict = [[NSMutableDictionary alloc] init];
            objc_setAssociatedObject(self, &key, actingClassThreadsDict, OBJC_ASSOCIATION_RETAIN);
        }
    }

    // Use NSNumber as the per-thread key instead of +stringWithFormat: — the variadic
    // format path (vfprintf) was crashing under deep swizzling recursion (e.g. broken
    // Xamarin/MAUI swizzling re-entering viewWillLayoutSubviews) when the stack was
    // near exhaustion. NSNumber avoids the variadic machinery and the signed/unsigned
    // mismatch with mach_port_t.
    NSNumber* threadId = nil;
    NSMutableDictionary* actingClassStackDict = nil;
    @try {
        threadId = @(pthread_mach_thread_np(pthread_self()));
        if (threadId == nil) {
            return nil;
        }
        @synchronized(actingClassThreadsDict) {
            actingClassStackDict = [actingClassThreadsDict objectForKey:threadId];

            if (actingClassStackDict == nil) {
                actingClassStackDict = [[NSMutableDictionary alloc] init];
                [actingClassThreadsDict setObject:actingClassStackDict forKey:threadId];
            }
        }
        NSMutableArray* actingClassStack = [actingClassStackDict objectForKey:selector];
        if (!actingClassStack) {
            /*
             * the associatedObject will persist for the lifetime of the object
             * but will be release after the object is dealloced.
             */
            actingClassStack = [[NSMutableArray alloc] init];
            [actingClassStackDict setObject:actingClassStack forKey:selector];
        }
        return actingClassStack;
    }
    @catch (NSException* exception) {
        return nil;
    }
}


// Returns the per-thread dictionary mapping selector -> NSNumber(depth) for self.
// Mirrors the storage strategy of NRMA_actingClassArray but tracks how many times
// a handler for a given (self, selector) is active on the current thread.
static NSMutableDictionary* NRMA_selectorDepthDict(id self)
{
    if (self == nil) {
        return nil;
    }

    NSMutableDictionary* depthThreadsDict = nil;
    @synchronized(__NRMAActingClassLock) {
        depthThreadsDict = objc_getAssociatedObject(self, &depthKey);

        if (depthThreadsDict == nil) {
            depthThreadsDict = [[NSMutableDictionary alloc] init];
            objc_setAssociatedObject(self, &depthKey, depthThreadsDict, OBJC_ASSOCIATION_RETAIN);
        }
    }

    NSNumber* threadId = nil;
    NSMutableDictionary* selectorDepthDict = nil;
    @try {
        threadId = @(pthread_mach_thread_np(pthread_self()));
        if (threadId == nil) {
            return nil;
        }
        @synchronized(depthThreadsDict) {
            selectorDepthDict = [depthThreadsDict objectForKey:threadId];

            if (selectorDepthDict == nil) {
                selectorDepthDict = [[NSMutableDictionary alloc] init];
                [depthThreadsDict setObject:selectorDepthDict forKey:threadId];
            }
        }
        return selectorDepthDict;
    }
    @catch (NSException* exception) {
        return nil;
    }
}

NSInteger NRMA_enterSelector(id self, NSString* selector)
{
    NSMutableDictionary* depthDict = NRMA_selectorDepthDict(self);
    if (depthDict == nil || selector == nil) {
        return 0;
    }
    @synchronized(depthDict) {
        NSInteger depth = [[depthDict objectForKey:selector] integerValue] + 1;
        [depthDict setObject:@(depth) forKey:selector];
        return depth;
    }
}

NSInteger NRMA_exitSelector(id self, NSString* selector)
{
    NSMutableDictionary* depthDict = NRMA_selectorDepthDict(self);
    if (depthDict == nil || selector == nil) {
        return 0;
    }
    @synchronized(depthDict) {
        NSInteger depth = [[depthDict objectForKey:selector] integerValue] - 1;
        if (depth <= 0) {
            [depthDict removeObjectForKey:selector];
            return 0;
        }
        [depthDict setObject:@(depth) forKey:selector];
        return depth;
    }
}

