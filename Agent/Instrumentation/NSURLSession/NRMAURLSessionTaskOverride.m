//
//  NRURLSessionTaskOverride.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 3/20/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionTaskOverride.h"
#import "NRMAURLSessionOverride.h"
#import "NRTimer.h"
#import "NRMAMethodSwizzling.h"
#import <objc/runtime.h>
#import "NRLogger.h"
#import "NRMAHTTPUtilities.h"
#import "NRMANetworkFacade.h"
#import "NRMAFlags.h"

static IMP NRMAOriginal__resume;
static IMP NRMAOriginal__urlSessionTask_SetState;
static Class __NRMAConcreteClass;

@implementation NRMAURLSessionTaskOverride

static const NSString* lock = @"com.newrelic.urlsessiontask.instrumentation.lock";
+ (void) instrumentConcreteClass:(Class)clazz
{
    // Instrument NSURLSessionTask resume.
    // we can avoid a synchronization block if we check to make sure it's nil first!
    if (clazz && NRMAOriginal__resume == nil) {
        //replace NSURLSessionTask -resume method
        @synchronized(lock) {
            if ([clazz instancesRespondToSelector:@selector(resume)] && NRMAOriginal__resume == nil) {
                
                __NRMAConcreteClass = clazz; //save the class we swizzled so we can de-swizzle
                
                NRMAOriginal__resume = NRMASwapImplementations(clazz, @selector(resume), (IMP)NRMAOverride__resume);
            }
        }
    }
    
    // We'll only instrument setState if the user enables Swift async URLSession support.
    if (![NRMAFlags shouldEnableSwiftAsyncURLSessionSupport]) return;

    // In iOS 13+ we instrument NSURLSessionTask:setState
    if (@available(iOS 13, tvOS 13, *)) {
        // Instrument NSURLSession setState
        if (clazz && NRMAOriginal__urlSessionTask_SetState == nil) {
            //replace NSURLSessionTask -setState: method
            @synchronized(lock) {
                if ([clazz instancesRespondToSelector:@selector(setState:)] && NRMAOriginal__urlSessionTask_SetState == nil) {
                    
                    __NRMAConcreteClass = clazz; //save the class we swizzled so we can de-swizzle
                    
                    NRMAOriginal__urlSessionTask_SetState = NRMASwapImplementations(clazz, @selector(setState:), (IMP)NRMAOverride__urlSessionTask_SetState);
                }
            }
        }
    }
}

+ (void) deinstrument
{
    if (NRMAOriginal__resume != nil) {
        if (sizeof(__NRMAConcreteClass) == sizeof(Class)) {
            //verify __NRConcreteClass is a Class struct
            Class clazz = __NRMAConcreteClass;
            NRMASwapImplementations(clazz, @selector(resume), (IMP)NRMAOriginal__resume);

            NRMAOriginal__resume = nil;
        }
    }
    
    // In iOS 13+ we instrument NSURLSessionTask:setState
    if (@available(iOS 13, tvOS 13, *)) {
        if (NRMAOriginal__urlSessionTask_SetState != nil) {
            if (sizeof(__NRMAConcreteClass) == sizeof(Class)) {
                //verify __NRConcreteClass is a Class struct
                Class clazz = __NRMAConcreteClass;
                NRMASwapImplementations(clazz, @selector(setState:), (IMP)NRMAOriginal__urlSessionTask_SetState);

                NRMAOriginal__urlSessionTask_SetState = nil;
            }
        }
    }
}

+ (NSInteger) statusCode:(NSURLResponse*)response {
    return [response isKindOfClass:[NSHTTPURLResponse class]] ? [((NSHTTPURLResponse*)response) statusCode] : -1;
}

// Currently we support NSURLSessionDataTask, NSURLSessionDownloadTask, and NSURLSessionUploadTask.
+ (bool) isSupportedTaskType:(NSURLSessionTask*) task {
    return [task isKindOfClass:[NSURLSessionDataTask class]] || [task isKindOfClass:[NSURLSessionDownloadTask class]] || [task isKindOfClass:[NSURLSessionUploadTask class]];
}

@end

void NRMAOverride__resume(id self, SEL _cmd)
{
    if (((NSURLSessionTask*)self).state == NSURLSessionTaskStateSuspended) {

        // The only state resume will start a task is from Suspended.
        // and since we are only instrumenting NSURLSessionUploadTask and
        // NSURLSessionDataTask we only need to start a new timer on this transmission
        // since those two restart if they are suspended.

        NRMA__setTimerForSessionTask(self, [NRTimer new]);
    }
    //call original method
    ((void(*)(id,SEL))NRMAOriginal__resume)(self,_cmd);
}

// This is the only way we have right now to record an swift async await web request.
void NRMAOverride__urlSessionTask_SetState(NSURLSessionTask* task, SEL _cmd, NSURLSessionTaskState *newState)
{
    @synchronized(lock) {
        @synchronized(task) {
            if ([NRMAURLSessionTaskOverride isSupportedTaskType: task]) {
                // Checking for NEW_RELIC_CROSS_PROCESS_ID_HEADER_KEY in the headers here. The data usually isn't link to the task yet here so, if that header exists we are handling the task elsewhere and have a better chance of getting the data so we don't need to record it here.
                NSURLRequest  *currentRequest = task.currentRequest;

                if (currentRequest == nil) {
                    return;
                }

                if ([currentRequest valueForHTTPHeaderField:NEW_RELIC_CROSS_PROCESS_ID_HEADER_KEY] != nil) {
                    return;
                }

                NSURL *url = [currentRequest URL];
                if (url != nil &&
                    newState != NSURLSessionTaskStateRunning && task.state == NSURLSessionTaskStateRunning) {

                    // Added this section to add Distributed Tracing traceId\trace.id, guid,id and payload.
                    //1
                    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:currentRequest];
                    mutableRequest = [NRMAHTTPUtilities addConnectivityHeaderAndPayload:mutableRequest];

                    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
                    [NRMAHTTPUtilities attachPayload:payload
                                                  to:task.originalRequest];

                    // get response code
                    NSUInteger responseCode = [NRMAURLSessionTaskOverride statusCode:task.response];
                    if (responseCode != -1) {
                        NSData *data = NRMA__getDataForSessionTask(task);
                        NRMA__recordTask(task, data, task.response, task.error);
                    }
                }
            }
        }
    }
    if (NRMAOriginal__urlSessionTask_SetState!= nil) {
        // Call original setState function.
        ((void(*)(NSURLSessionTask *,SEL,NSURLSessionTaskState *))NRMAOriginal__urlSessionTask_SetState)(task, _cmd, newState);
    }
}


