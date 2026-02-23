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
    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] instrumentConcreteClass: %@", NSStringFromClass(clazz));

    // Instrument NSURLSessionTask resume.
    // we can avoid a synchronization block if we check to make sure it's nil first!
    if (clazz && NRMAOriginal__resume == nil) {
        //replace NSURLSessionTask -resume method
        @synchronized(lock) {
            if ([clazz instancesRespondToSelector:@selector(resume)] && NRMAOriginal__resume == nil) {

                __NRMAConcreteClass = clazz; //save the class we swizzled so we can de-swizzle

                NRMAOriginal__resume = NRMASwapImplementations(clazz, @selector(resume), (IMP)NRMAOverride__resume);
                NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] swizzled -resume on %@", NSStringFromClass(clazz));
            } else {
                NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] -resume already swizzled or class nil, skipping for %@", NSStringFromClass(clazz));
            }
        }
    } else {
        NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] -resume already swizzled (NRMAOriginal__resume != nil), skipping for %@", NSStringFromClass(clazz));
    }

    // We'll only instrument setState if the user enables Swift async URLSession support.
    if (![NRMAFlags shouldEnableSwiftAsyncURLSessionSupport]) {
        NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] Swift async URLSession support disabled, skipping setState: swizzle for %@", NSStringFromClass(clazz));
        return;
    }

    // In iOS 13+ we instrument NSURLSessionTask:setState
    if (@available(iOS 13, tvOS 13, *)) {
        // Instrument NSURLSession setState
        if (clazz && NRMAOriginal__urlSessionTask_SetState == nil) {
            //replace NSURLSessionTask -setState: method
            @synchronized(lock) {
                if ([clazz instancesRespondToSelector:@selector(setState:)] && NRMAOriginal__urlSessionTask_SetState == nil) {

                    __NRMAConcreteClass = clazz; //save the class we swizzled so we can de-swizzle

                    NRMAOriginal__urlSessionTask_SetState = NRMASwapImplementations(clazz, @selector(setState:), (IMP)NRMAOverride__urlSessionTask_SetState);
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] swizzled -setState: on %@", NSStringFromClass(clazz));
                } else {
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] -setState: already swizzled or class nil, skipping for %@", NSStringFromClass(clazz));
                }
            }
        } else {
            NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] -setState: already swizzled (NRMAOriginal__urlSessionTask_SetState != nil), skipping for %@", NSStringFromClass(clazz));
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
    NSURLSessionTask *task = (NSURLSessionTask *)self;
    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] resume: taskIdentifier=%lu state=%ld URL=%@",
                     (unsigned long)task.taskIdentifier, (long)task.state,
                     task.currentRequest.URL.absoluteString ?: @"nil");

    if (task.state == NSURLSessionTaskStateSuspended) {

        // The only state resume will start a task is from Suspended.
        // and since we are only instrumenting NSURLSessionUploadTask and
        // NSURLSessionDataTask we only need to start a new timer on this transmission
        // since those two restart if they are suspended.

        NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] resume: task is Suspended, creating new timer for taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
        NRMA__setTimerForSessionTask(self, [NRTimer new]);
    } else {
        NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] resume: task state=%ld is not Suspended, no timer created for taskIdentifier=%lu",
                         (long)task.state, (unsigned long)task.taskIdentifier);
    }
    //call original method
    ((void(*)(id,SEL))NRMAOriginal__resume)(self,_cmd);
}

// This is the only way we have right now to record an swift async await web request.
void NRMAOverride__urlSessionTask_SetState(NSURLSessionTask* task, SEL _cmd, NSURLSessionTaskState newState)
{
    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: taskIdentifier=%lu currentState=%ld newState=%ld URL=%@",
                     (unsigned long)task.taskIdentifier, (long)task.state, (long)newState,
                     task.currentRequest.URL.absoluteString ?: @"nil");
    @synchronized(lock) {
        @synchronized(task) {
            if ([NRMAURLSessionTaskOverride isSupportedTaskType: task]) {

                NSNumber *isHandled = objc_getAssociatedObject(task, NRMAHandledRequestKey);

                if (isHandled != nil && [isHandled boolValue]) {
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: taskIdentifier=%lu already handled via swizzled task factory, delegating to original setState:", (unsigned long)task.taskIdentifier);
                    if (NRMAOriginal__urlSessionTask_SetState!= nil) {
                        // Call original setState function.
                        ((void(*)(NSURLSessionTask *,SEL,NSURLSessionTaskState))NRMAOriginal__urlSessionTask_SetState)(task, _cmd, newState);
                    }
                    return;
                }

                NSURLRequest  *currentRequest = task.currentRequest;

                if(currentRequest == nil) {
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: taskIdentifier=%lu currentRequest is nil, skipping instrumentation", (unsigned long)task.taskIdentifier);
                    return;
                }

                NSURL *url = [currentRequest URL];
                if (url != nil) {
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: instrumenting Swift async task taskIdentifier=%lu URL=%@", (unsigned long)task.taskIdentifier, url.absoluteString);

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

                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: newState=%ld taskState=%ld taskIdentifier=%lu dataLength=%lu",
                                     (long)newState, (long)task.state, (unsigned long)task.taskIdentifier, (unsigned long)data.length);

                    if (newState == NSURLSessionTaskStateCompleted) {
                        NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: task reached Completed state, calling NRMA__recordTask for taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
                        NRMA__recordTask(task, data, task.response, task.error);
                    }
                } else {
                    NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: taskIdentifier=%lu URL is nil, skipping instrumentation", (unsigned long)task.taskIdentifier);
                }
            } else {
                NRLOG_AGENT_DEBUG(@"[NSURLSessionTask] setState: taskIdentifier=%lu task type not supported (class=%@), skipping",
                                 (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
            }
        }
    }
    if (NRMAOriginal__urlSessionTask_SetState!= nil) {
        // Call original setState function.
        ((void(*)(NSURLSessionTask *,SEL,NSURLSessionTaskState))NRMAOriginal__urlSessionTask_SetState)(task, _cmd, newState);
    }
}


