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
#import "NRConstants.h"

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
void NRMAOverride__urlSessionTask_SetState(NSURLSessionTask* task, SEL _cmd, NSURLSessionTaskState newState)
{
    @synchronized(lock) {
        @synchronized(task) {
            if ([NRMAURLSessionTaskOverride isSupportedTaskType: task]) {

                NSNumber *isHandled = objc_getAssociatedObject(task, NRMAHandledRequestKey);

                if (isHandled != nil && [isHandled boolValue]) {
                    if (NRMAOriginal__urlSessionTask_SetState!= nil) {
                        // Call original setState function.
                        ((void(*)(NSURLSessionTask *,SEL,NSURLSessionTaskState))NRMAOriginal__urlSessionTask_SetState)(task, _cmd, newState);
                    }
                    return;
                }

                NSURLRequest  *currentRequest = task.currentRequest;

                if(currentRequest == nil) {
                    return;
                }

                NSURL *url = [currentRequest URL];
                if (url != nil) {

                    // Added this section to add Distributed Tracing traceId\trace.id, guid,id and payload.
                    //1
                    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:currentRequest];
                    mutableRequest = [NRMAHTTPUtilities addConnectivityHeaderAndPayload:mutableRequest];
                    // 2
                    if([NRMAFlags shouldEnableNewEventSystem]){
                        NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest];
                        [NRMAHTTPUtilities attachNRMAPayload:payload
                                                      to:task.originalRequest];
                    } else {
                        NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
                        [NRMAHTTPUtilities attachPayload:payload
                                                      to:task.originalRequest];
                    }


                    NSData *data = NRMA__getDataForSessionTask(task);
                    
                    // Note: For Swift async/await URLSession requests, response body data cannot be captured
                    // because it's returned directly to the caller and never stored in the task object.
                    // Delegate callbacks (where we normally capture data) are not invoked for async requests.
                    // URL association for images also will not work for async/await URLSession requests.
                    //
                    // However, we can still successfully record:
                    // - Request timing (duration)
                    // - HTTP status codes
                    // - Response headers
                    // - Byte counts (task.countOfBytesSent, task.countOfBytesReceived)
                    // - Error information
                    //
                    // This provides valuable performance data even without the response body.
                    
                    // log the task and data that we will record
                    //NSLog(@"NRMAOverride__urlSessionTask_SetState newState: %ld, taskState:%ld  task: %@ data: %@", (long) newState, (long)task.state, task, data);

                    if (newState == NSURLSessionTaskStateCompleted) {
                        // NSLog(@"NRMAOverride NRMA__recordTask called because newState  == NSURLSessionTaskStateCompleted  newState: %ld, taskState:%ld  task: %@ data: %@", (long) newState, (long)task.state, task, data);

                        NRMA__recordTask(task, data, task.response, task.error);
                    }
                }
            }
        }
    }
    if (NRMAOriginal__urlSessionTask_SetState!= nil) {
        // Call original setState function.
        ((void(*)(NSURLSessionTask *,SEL,NSURLSessionTaskState))NRMAOriginal__urlSessionTask_SetState)(task, _cmd, newState);
    }
}


