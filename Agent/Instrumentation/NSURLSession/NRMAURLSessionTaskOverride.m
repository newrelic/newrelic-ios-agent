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

#define NR_DEBUG_FETCH_TYPE_PROBE 1
#if NR_DEBUG_FETCH_TYPE_PROBE
static void NRMA__probeAsyncTaskMetrics(NSURLSessionTask *task) {
    @try {
        id m = nil;
        @try { m = [task valueForKey:@"_metrics"]; } @catch (...) {}
        if (m == nil) {
            @try { m = [task valueForKey:@"metrics"]; } @catch (...) {}
        }
        if (m == nil) {
            NRLOG_AGENT_INFO(@"[NRFetchProbe asyncSetState] url=%@ metrics=nil",
                             task.originalRequest.URL.absoluteString);
            return;
        }
        NSInteger appVisibleStatus = [task.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)task.response statusCode] : -1;

        // Public path: m is NSURLSessionTaskMetrics on iOS < 26.
        if ([m respondsToSelector:@selector(transactionMetrics)]) {
            NSURLSessionTaskMetrics *pub = (NSURLSessionTaskMetrics *)m;
            NSURLSessionTaskTransactionMetrics *last = pub.transactionMetrics.lastObject;
            NSInteger wireStatus = [last.response isKindOfClass:[NSHTTPURLResponse class]]
                ? [(NSHTTPURLResponse *)last.response statusCode] : -1;
            NRLOG_AGENT_INFO(@"[NRFetchProbe asyncSetState] url=%@ txCount=%lu fetchType=%ld "
                             @"finalWireStatus=%ld appVisibleStatus=%ld",
                             task.originalRequest.URL.absoluteString,
                             (unsigned long)pub.transactionMetrics.count,
                             (long)last.resourceFetchType,
                             (long)wireStatus,
                             (long)appVisibleStatus);
            return;
        }

        // Private path on iOS 26+: __CFN_TaskMetrics. resourceFetchType is unreachable;
        // log what's available.
        SEL daemonTxSel = NSSelectorFromString(@"_daemon_transactionMetrics");
        if (![m respondsToSelector:daemonTxSel]) {
            NRLOG_AGENT_INFO(@"[NRFetchProbe asyncSetState] url=%@ unsupported metrics class=%@ appVisibleStatus=%ld",
                             task.originalRequest.URL.absoluteString,
                             NSStringFromClass([m class]),
                             (long)appVisibleStatus);
            return;
        }
        IMP imp = [m methodForSelector:daemonTxSel];
        NSArray *txs = ((NSArray *(*)(id, SEL))imp)(m, daemonTxSel);
        int64_t wireBodyBytes = -1;
        SEL bodyBytesSel = NSSelectorFromString(@"_daemon_responseBodyTransferSize");
        id lastTx = txs.lastObject;
        if ([lastTx respondsToSelector:bodyBytesSel]) {
            NSMethodSignature *sig = [lastTx methodSignatureForSelector:bodyBytesSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            inv.selector = bodyBytesSel;
            [inv invokeWithTarget:lastTx];
            [inv getReturnValue:&wireBodyBytes];
        }
        NRLOG_AGENT_INFO(@"[NRFetchProbe asyncSetState] url=%@ private=%@ txCount=%lu "
                         @"wireBodyBytes=%lld appVisibleStatus=%ld "
                         @"(fetchType requires delegate path)",
                         task.originalRequest.URL.absoluteString,
                         NSStringFromClass([m class]),
                         (unsigned long)txs.count,
                         (long long)wireBodyBytes,
                         (long)appVisibleStatus);
    } @catch (NSException *e) {
        NRLOG_AGENT_INFO(@"[NRFetchProbe asyncSetState] exception: %@", e);
    }
}
#endif

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

                    if (newState == NSURLSessionTaskStateCompleted) {
                        // The task has finished. Do NOT create a mutable copy of, or attach
                        // associated objects to, the task's request here. At completion CFNetwork
                        // may be concurrently serializing that same request's header dictionary
                        // into the shared URL cache (com.apple.CFNetwork.CacheDB-write queue).
                        // NSURLRequest header dictionaries are not thread-safe, so mutating/copying
                        // them here races with CFNetwork's cache write and can leave a dangling
                        // object that CFNetwork later walks into (CFGetTypeID crash). Injecting
                        // distributed-tracing headers at completion is also pointless because the
                        // request has already been sent. Only read immutable snapshots to record.
                        NSData *data = NRMA__getDataForSessionTask(task);
                        NSURLResponse *response = task.response;
                        NSError *taskError = task.error;

#if NR_DEBUG_FETCH_TYPE_PROBE
                        NRMA__probeAsyncTaskMetrics(task);
#endif
                        NRMA__recordTask(task, data, task.response, task.error);
                    }
                    else {
                        // The task is starting. Add Distributed Tracing traceId\trace.id, guid, id
                        // and payload before the request goes out. This is safe because the task
                        // is not yet being torn down / cached by CFNetwork.
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


