//
//  NRMAURLSessionDataTaskOverride.m
//  NSURLSessionExperiment
//
//  Created by Bryce Buchanan on 3/14/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionOverride.h"
#import "NRMAMethodSwizzling.h"
#import <objc/runtime.h>
#import "NRMAMethodSwizzling.h"
#import "NRMAMeasurements.h"
#import "NRMAURLSessionTaskOverride.h"
#import "NewRelicInternalUtils.h"
#import "NRMAExceptionHandler.h"
#import "NRMAURLSessionTaskDelegate.h"
#import "NRMANSURLConnectionSupport+private.h"
#import "NRMAHTTPUtilities.h"
#import "NRMAAssociate.h"
#import "NRMAURLSessionTaskSearch.h"
#import "NRMAFlags.h"
#import "NRMANSCacheInstrumentation.h"

#define NRMASwizzledMethodPrefix @"_NRMAOverride__"

IMP NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue;

IMP NRMAOriginal__dataTaskWithRequest;
IMP NRMAOriginal__dataTaskWithRequest_completionHandler;
IMP NRMAOriginal__dataTaskWithURL;
IMP NRMAOriginal__dataTaskWithURL_completionHandler;

IMP NRMAOriginal__uploadTaskWithRequest_fromFile;
IMP NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler;
IMP NRMAOriginal__uploadTaskWithRequest_fromData;
IMP NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler;
IMP NRMAOriginal__uploadTaskWithStreamedRequest;

void NRMA__instanceSwizzleIfNotSwizzled(Class clazz, SEL selector, IMP newImplementation);

// ---------------------------------------------------------------------------
// URLCache hit detection helpers
// ---------------------------------------------------------------------------

// Checks NSURLCache at task-creation time and stores a flag on the task if a
// valid cached response exists.  Call this right after the task is created,
// before -resume is ever called.  Uses the original (pre-NR-header) request so
// the cache lookup matches the key used when the response was originally stored.
static void NRMA__markPreflightCacheHit(NSURLRequest *request, NSURLSessionTask *task) {
    if (task == nil || request == nil) return;

    // Policies that force a network reload make a cache hit impossible.
    if (request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData ||
        request.cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] preflight cache: policy=%lu forces network for taskIdentifier=%lu URL=%@",
                         (unsigned long)request.cachePolicy,
                         (unsigned long)task.taskIdentifier,
                         request.URL.absoluteString);
        return;
    }

    BOOL hit = NO;

    // 1. Check the HTTP-level NSURLCache.
    NSCachedURLResponse *cached = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    if (cached != nil) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] preflight cache: NSURLCache HIT taskIdentifier=%lu URL=%@",
                         (unsigned long)task.taskIdentifier, request.URL.absoluteString);
        hit = YES;
    } else {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] preflight cache: NSURLCache MISS taskIdentifier=%lu URL=%@",
                         (unsigned long)task.taskIdentifier, request.URL.absoluteString);
    }

    // 2. Also check any NSCache instances registered with NRMANSCacheInstrumentation.
    //    The registry reverse-index maps URL → (cache, key) so the lookup is O(1)
    //    and uses the original (pre-swizzle) IMP — no spurious event log entries.
    if (!hit && [NRMANSCacheInstrumentation hasCachedObjectForURL:request.URL]) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] preflight cache: NSCache HIT taskIdentifier=%lu URL=%@",
                         (unsigned long)task.taskIdentifier, request.URL.absoluteString);
        hit = YES;
    }

    if (hit) {
        objc_setAssociatedObject(task, kNRPreflightCacheHitKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}


@interface PayloadHolder : NSObject
@property (nonatomic, retain) NRMAPayload *objcPayload;
@property (nonatomic, retain) NRMAPayloadContainer *cppPayload;
@end

@implementation PayloadHolder
@end

@interface NRMAIMPContainer : NSObject
@property(readonly) IMP imp;
- (instancetype) initWithImp:(IMP)imp;
@end
@implementation NRMAIMPContainer

- (instancetype) initWithImp:(IMP)imp
{
    self = [super init];
    if (self) {
        _imp = imp;
    }
    return self;
}

@end
@implementation NRMAURLSessionOverride

+ (void) beginInstrumentation
{
    NRLOG_AGENT_DEBUG(@"[NSURLSession] beginInstrumentation: starting swizzle setup");
    id clazz = objc_getClass("NSURLSession");
    if (clazz) {
        //session task overrides
        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling sessionWithConfiguration:delegate:delegateQueue:");
        NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue = NRMASwapImplementations(clazz,@selector(sessionWithConfiguration:delegate:delegateQueue:), (IMP)NRMAOverride__sessionWithConfiguration_delegate_delegateQueue);

        /*
         * In iOS 13 the definition of NSURLSession changed under the hood, and the way we instrument these methods has changed. iOS 13 specific requirements are wrapped in a @available.
         */
        if (@available(iOS 13, *)) {
            NRLOG_AGENT_DEBUG(@"[NSURLSession] iOS 13+: resolving concrete NSURLSession class for method swizzling");
            id obj = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            id concreteClass = [obj class];
            NRLOG_AGENT_DEBUG(@"[NSURLSession] iOS 13+: concrete class resolved to %@", NSStringFromClass(concreteClass));
            clazz = concreteClass;
        }
        // Data Task  method overrides
        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling dataTaskWithRequest:");
        NRMAOriginal__dataTaskWithRequest = NRMASwapImplementations(clazz, @selector(dataTaskWithRequest:), (IMP)NRMAOverride__dataTaskWithRequest);

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling dataTaskWithURL:");
        NRMAOriginal__dataTaskWithURL = NRMASwapImplementations(clazz, @selector(dataTaskWithURL:), (IMP)NRMAOverride__dataTaskWithURL);

        if (@available(iOS 13, *)) { //in os prior to 13 dataTaskWithURL would call dataTaskWithRequest in turn. This is no longer the case, and must be instrumented explicitly.
            NRLOG_AGENT_DEBUG(@"[NSURLSession] iOS 13+: Swizzling dataTaskWithURL:completionHandler:");
            NRMAOriginal__dataTaskWithURL_completionHandler = NRMASwapImplementations(clazz, @selector(dataTaskWithURL:completionHandler:), (IMP) NRMAOverride__dataTaskWithURL_completionHandler);
        }

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling dataTaskWithRequest:completionHandler:");
        NRMAOriginal__dataTaskWithRequest_completionHandler = NRMASwapImplementations(clazz, @selector(dataTaskWithRequest:completionHandler:), (IMP)NRMAOverride__dataTaskWithRequest_completionHandler);

        //upload tasks method overrides
        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling uploadTaskWithRequest:fromData:");
        NRMAOriginal__uploadTaskWithRequest_fromData = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromData:), (IMP)NRMAOverride__uploadTaskWithRequest_fromData);

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling uploadTaskWithRequest:fromData:completionHandler:");
        NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromData:completionHandler:), (IMP)NRMAOverride__uploadTaskWithRequest_fromData_completionHandler);

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling uploadTaskWithRequest:fromFile:completionHandler:");
        NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromFile:completionHandler:), (IMP)NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler);

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling uploadTaskWithRequest:fromFile:");
        NRMAOriginal__uploadTaskWithRequest_fromFile = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromFile:), (IMP)NRMAOverride__uploadTaskWithRequest_fromFile);

        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swizzling uploadTaskWithStreamedRequest:");
        NRMAOriginal__uploadTaskWithStreamedRequest=NRMASwapImplementations(clazz,@selector(uploadTaskWithStreamedRequest:),(IMP)NRMAOverride__uploadTaskWithStreamedRequest);
    } else {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] NSURLSession class not found, skipping instrumentation");
    }

    if ([NRMAFlags shouldEnableSwiftAsyncURLSessionSupport]) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swift async URLSession support enabled, swizzling task classes");
        [self swizzleURLSessionTask];
    } else {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] Swift async URLSession support disabled, skipping task class swizzle");
    }
    NRLOG_AGENT_DEBUG(@"[NSURLSession] beginInstrumentation: complete");
}

+ (void) deinstrument
{
    id clazz = objc_getClass("NSURLSession");
    if (clazz) {
        //session task overrides
        NRMASwapImplementations(clazz, @selector(sessionWithConfiguration:delegate:delegateQueue:), (IMP)NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue);
        
        id obj = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        id concreteClass = [obj class];
        clazz = concreteClass;
        NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue = nil;
        
        // Data Task  method overrides
        NRMASwapImplementations(clazz,@selector(dataTaskWithRequest:), (IMP)NRMAOriginal__dataTaskWithRequest);
        NRMAOriginal__dataTaskWithRequest = nil;

        if (@available(iOS 13, *)) { // see note in +(void)instrument;
            NRMASwapImplementations(clazz, @selector(dataTaskWithURL:completionHandler:), (IMP)NRMAOriginal__dataTaskWithURL_completionHandler);
            NRMAOriginal__dataTaskWithURL_completionHandler = nil;
        }
        
        NRMASwapImplementations(clazz,@selector(dataTaskWithURL:),(IMP)NRMAOriginal__dataTaskWithURL);
        NRMAOriginal__dataTaskWithURL = nil;
        
        NRMASwapImplementations(clazz,@selector(dataTaskWithRequest:completionHandler:),(IMP)NRMAOriginal__dataTaskWithRequest_completionHandler);
        NRMAOriginal__dataTaskWithRequest_completionHandler = nil;
        
        //upload tasks method overrides
        NRMASwapImplementations(clazz,@selector(uploadTaskWithRequest:fromData:),(IMP)NRMAOriginal__uploadTaskWithRequest_fromData);
        NRMAOriginal__uploadTaskWithRequest_fromData = nil;
        
        NRMASwapImplementations(clazz,@selector(uploadTaskWithRequest:fromData:completionHandler:),(IMP)NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler);
        NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler = nil;
        
        NRMASwapImplementations(clazz,@selector(uploadTaskWithRequest:fromFile:completionHandler:),(IMP)NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler);
        NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler= nil;
        
        NRMASwapImplementations(clazz,@selector(uploadTaskWithRequest:fromFile:),(IMP)NRMAOriginal__uploadTaskWithRequest_fromFile);
        NRMAOriginal__uploadTaskWithRequest_fromFile = nil;
        
        NRMASwapImplementations(clazz,@selector(uploadTaskWithStreamedRequest:),(IMP)NRMAOriginal__uploadTaskWithStreamedRequest);
        NRMAOriginal__uploadTaskWithStreamedRequest = nil; 
    }

    [NRMAURLSessionTaskOverride deinstrument];
}

+ (void)swizzleURLSessionTask
{
    NSArray<Class> *classesToSwizzle = [NRMAURLSessionTaskSearch urlSessionTaskClasses];
    NRLOG_AGENT_DEBUG(@"[NSURLSession] swizzleURLSessionTask: found %lu concrete task class(es) to instrument", (unsigned long)classesToSwizzle.count);
    for (Class classToSwizzle in classesToSwizzle) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] swizzleURLSessionTask: instrumenting %@", NSStringFromClass(classToSwizzle));
        [NRMAURLSessionTaskOverride instrumentConcreteClass:classToSwizzle];
    }
}

@end

NSURLSession* NRMAOverride__sessionWithConfiguration_delegate_delegateQueue(id self,
                                                                          SEL _cmd,
                                                                          NSURLSessionConfiguration* configuration,
                                                                          id<NSURLSessionDelegate> delegate,
                                                                          NSOperationQueue* queue)
{
    NRLOG_AGENT_DEBUG(@"[NSURLSession] sessionWithConfiguration:delegate:delegateQueue: delegateClass=%@ wrapping=%@",
                     delegate ? NSStringFromClass([delegate class]) : @"nil",
                     delegate ? @"YES" : @"NO");
    NSURLSession* session =  ((id(*)(id, SEL, id, id, id))NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue)(self,
                                                                                         _cmd,
                                                                                         configuration,
                                                                                         delegate?[[NRMAURLSessionTaskDelegate alloc] initWithOriginalDelegate:delegate]:nil,
                                                                                         queue);
    NRLOG_AGENT_DEBUG(@"[NSURLSession] sessionWithConfiguration:delegate:delegateQueue: session created, cachePolicy=%lu", (unsigned long)configuration.requestCachePolicy);
    return session;
}


#pragma mark - NSURLSessionDataTask overrides

NSURLSessionTask* NRMAOverride__dataTaskWithRequest(id self, SEL _cmd, NSURLRequest* request)
{
    if (self == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. self is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }
    if (_cmd == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. _cmd is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }
    if (request == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. request is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }
    if (NRMAOriginal__dataTaskWithRequest == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. NRMAOriginal__dataTaskWithRequest is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }
    
    if (request.URL == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. [begin] Request has no URL. Returning nil."];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    } else {
        NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. [begin] Request appears good, instrumenting request: %@", request.URL.absoluteString];
        NRLOG_AGENT_VERBOSE(@"%@", res);
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest: URL=%@ method=%@ cachePolicy=%lu timeout=%.1f",
                     request.URL.absoluteString, request.HTTPMethod,
                     (unsigned long)request.cachePolicy, request.timeoutInterval);

    IMP originalImp = NRMAOriginal__dataTaskWithRequest;

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];

    PayloadHolder *payloadHolder = [[PayloadHolder alloc] init];
    if([NRMAFlags shouldEnableNewEventSystem]) {
        payloadHolder.objcPayload = ([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]);
    } else {
        payloadHolder.cppPayload = ([NRMAHTTPUtilities addConnectivityHeader:mutableRequest]);
    }

    NSURLSessionTask* task = ((id(*)(id,SEL,NSURLRequest*))originalImp)(self,_cmd,mutableRequest);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
    // Preflight NSURLCache check — uses original request (pre-NR-header mutation) for accurate key match.
    NRMA__markPreflightCacheHit(request, task);

    if([NRMAFlags shouldEnableNewEventSystem]){
        [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload
                                      to:task.originalRequest];
    } else {
        [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload
                                      to:task.originalRequest];
    }

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];

    NSString *res = [NSString stringWithFormat:@"NRMAFEB08::NRMAOverride__dataTaskWithRequest. [end] Leaving after instrumenting request."];
    NRLOG_AGENT_VERBOSE(@"%@", res);

    return task;
}

/*
 * This method will not be utilized in os versions less than 13 due to branches in the above -[instrument] method. In 12 and below, -[NSURLSession dataTaskWithURL:completionHandler:] calls through to dataTaskWithRequest.
 */
NSURLSessionTask* NRMAOverride__dataTaskWithURL_completionHandler(id self, SEL _cmd, NSURL* url , void (^completionHandler)(NSData*,NSURLResponse*,NSError*)){
    return NRMAOverride__dataTaskWithRequest_completionHandler(self, _cmd, [NSURLRequest requestWithURL:url], completionHandler);
}

NSURLSessionTask* NRMAOverride__dataTaskWithRequest_completionHandler(id self, SEL _cmd,NSURLRequest* request , void (^completionHandler)(NSData*,NSURLResponse*,NSError*))
{
    IMP originalImp = NRMAOriginal__dataTaskWithRequest_completionHandler;

    if (originalImp == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__dataTaskWithRequest_completionHandler. NRMAOriginal__dataTaskWithRequest_completionHandler is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);

        return nil;
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest:completionHandler: URL=%@ method=%@ cachePolicy=%lu hasCompletionHandler=%@",
                     request.URL.absoluteString, request.HTTPMethod,
                     (unsigned long)request.cachePolicy, completionHandler ? @"YES" : @"NO");

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    __block NSURLSessionTask* task = nil;

    PayloadHolder *payloadHolder = [[PayloadHolder alloc] init];
    if([NRMAFlags shouldEnableNewEventSystem]) {
        payloadHolder.objcPayload = ([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]);
    } else {
        payloadHolder.cppPayload = ([NRMAHTTPUtilities addConnectivityHeader:mutableRequest]);
    }

    if (completionHandler == nil) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest:completionHandler: nil handler path, task will be tracked via delegate");
        task  = ((id(*)(id,SEL,NSURLRequest*,void(^)(NSData*,NSURLResponse*,NSError*)))originalImp)(self,_cmd,mutableRequest,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
        NRMA__markPreflightCacheHit(request, task);
        NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest:completionHandler: (nil handler) created task taskIdentifier=%lu class=%@",
                         (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
        return task;
    }

    task =  ((id(*)(id,SEL,NSURLRequest*,void(^)(NSData*,NSURLResponse*,NSError*)))originalImp)(self,_cmd,mutableRequest,^(NSData* data, NSURLResponse* response, NSError* error){

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest:completionHandler: block fired taskIdentifier=%lu dataLength=%lu error=%@",
                         (unsigned long)task.taskIdentifier, (unsigned long)data.length, error ?: @"nil");
        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    NRMA__markPreflightCacheHit(request, task);
    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithRequest:completionHandler: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));

    return task;
}

NSURLSessionTask* NRMAOverride__dataTaskWithURL(id self, SEL _cmd, NSURL* url)
{
    IMP originalImp = NRMAOriginal__dataTaskWithURL;

    if (originalImp == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__dataTaskWithURL. NRMAOriginal__dataTaskWithURL is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);

        return nil;
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithURL: URL=%@", url.absoluteString);

    NSURLSessionTask* task = ((id(*)(id,SEL,NSURL*))originalImp)(self,_cmd,url);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NRLOG_AGENT_DEBUG(@"[NSURLSession] dataTaskWithURL: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
    NRMA__markPreflightCacheHit([NSURLRequest requestWithURL:url], task);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    return task;
}

#pragma mark - NSURLSessionUploadTask Overrides

NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromFile(id self, SEL _cmd, NSURLRequest* request, NSURL* fileURL)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithRequest_fromFile;

    if (originalImp == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__uploadTaskWithRequest_fromFile. NRMAOriginal__uploadTaskWithRequest_fromFile is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);

        return nil;
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile: URL=%@ fileURL=%@",
                     request.URL.absoluteString, fileURL.absoluteString);

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    NSURLSessionTask* task = ((NSURLSessionTask*(*)(id,SEL,NSURLRequest*,NSURL*))originalImp)(self,_cmd,mutableRequest,fileURL);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if([NRMAFlags shouldEnableNewEventSystem]){
        NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest];
        [NRMAHTTPUtilities attachNRMAPayload:payload
                                      to:task.originalRequest];
    } else {
        NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
        [NRMAHTTPUtilities attachPayload:payload
                                      to:task.originalRequest];
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];

    return task;
}

NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromData(id self, SEL _cmd, NSURLRequest* request, NSData* data)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithRequest_fromData;

    if (originalImp == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__uploadTaskWithRequest_fromData. NRMAOriginal__uploadTaskWithRequest_fromData is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);

        return nil;
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData: URL=%@ bodyDataLength=%lu",
                     request.URL.absoluteString, (unsigned long)data.length);

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    NSURLSessionTask* task = ((NSURLSessionTask*(*)(id,SEL,NSURLRequest*,NSData*))originalImp)(self, _cmd, mutableRequest, data);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if([NRMAFlags shouldEnableNewEventSystem]){
        NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest];
        [NRMAHTTPUtilities attachNRMAPayload:payload to:task.originalRequest];
    } else {
        NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
        [NRMAHTTPUtilities attachPayload:payload to:task.originalRequest];
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];

    return task;
}

NSURLSessionTask* NRMAOverride__uploadTaskWithStreamedRequest(id self, SEL _cmd, NSURLRequest* request)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithStreamedRequest;

    if (originalImp == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__uploadTaskWithStreamedRequest. NRMAOriginal__uploadTaskWithStreamedRequest is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);

        return nil;
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithStreamedRequest: URL=%@", request.URL.absoluteString);

    NSURLSessionTask* task = ((NSURLSessionTask*(*)(id,SEL,NSURLRequest*))originalImp)(self, _cmd,request);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithStreamedRequest: created task taskIdentifier=%lu class=%@",
                     (unsigned long)task.taskIdentifier, NSStringFromClass([task class]));
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];

    return task;
}

NSURLSessionUploadTask* NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSURL* fileURL, void (^completionHandler)(NSData*,NSURLResponse*,NSError*))
{
    IMP originalIMP = NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler;

    if (originalIMP == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler. NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    __block NSURLSessionUploadTask* task = nil;
    PayloadHolder *payloadHolder = [[PayloadHolder alloc] init];
    if([NRMAFlags shouldEnableNewEventSystem]) {
        payloadHolder.objcPayload = ([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]);
    } else {
        payloadHolder.cppPayload = ([NRMAHTTPUtilities addConnectivityHeader:mutableRequest]);
    }
    
    if (completionHandler == nil) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile:completionHandler: nil handler, task tracked via delegate");
        task = ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSURL*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,fileURL,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile:completionHandler: (nil handler) created task taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
        return task;
    }

    task =  ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSURL*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,fileURL,^(NSData* data,
                                                                                                                                                        NSURLResponse* response,
                                                                                                                                                        NSError* error){
        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile:completionHandler: block fired taskIdentifier=%lu dataLength=%lu error=%@",
                         (unsigned long)task.taskIdentifier, (unsigned long)data.length, error ?: @"nil");
        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromFile:completionHandler: created task taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
    return task;

}

NSURLSessionUploadTask* NRMAOverride__uploadTaskWithRequest_fromData_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSData* bodyData, void (^completionHandler)(NSData*,NSURLResponse*,NSError*))
{
    IMP originalIMP = NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler;

    if (originalIMP == nil) {
        NSString *res = [NSString stringWithFormat:@"NRMAOverride__uploadTaskWithRequest_fromData_completionHandler. NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler is nil. returning nil"];
        NRLOG_AGENT_ERROR(@"%@", res);
        return nil;
    }

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    __block NSURLSessionUploadTask* task = nil;
    
    PayloadHolder *payloadHolder = [[PayloadHolder alloc] init];
    if([NRMAFlags shouldEnableNewEventSystem]) {
        payloadHolder.objcPayload = ([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]);
    } else {
        payloadHolder.cppPayload = ([NRMAHTTPUtilities addConnectivityHeader:mutableRequest]);
    }
    
    if (completionHandler == nil) {
        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData:completionHandler: nil handler, task tracked via delegate");
        task = ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSData*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,bodyData,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData:completionHandler: (nil handler) created task taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
        return task;
    }

    task =  ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSData*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,bodyData,^(NSData* data, NSURLResponse* response, NSError* error){

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData:completionHandler: block fired taskIdentifier=%lu dataLength=%lu error=%@",
                         (unsigned long)task.taskIdentifier, (unsigned long)data.length, error ?: @"nil");
        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    NRLOG_AGENT_DEBUG(@"[NSURLSession] uploadTaskWithRequest:fromData:completionHandler: created task taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
    return task;
}

void NRMA__recordTask(NSURLSessionTask* task, NSData* data, NSURLResponse* response, NSError* error)
{
    NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: taskIdentifier=%lu URL=%@ error=%@",
                     (unsigned long)task.taskIdentifier,
                     task.originalRequest.URL.absoluteString,
                     error ?: @"nil");
    @try {
        NRTimer* timer = NRMA__getTimerForSessionTask(task);
        // If there is no timer, let's not record this network activity. this could mean a session executed before task was instrumented or the request has already been instrumented by another handler.
        if (timer) {
            NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: timer found, elapsed=%.3fs bytesSent=%lld bytesReceived=%lld dataBodyLength=%lu",
                             timer.timeElapsedInSeconds, task.countOfBytesSent, task.countOfBytesReceived, (unsigned long)data.length);
            BOOL cacheHit = NRMA__isURLCacheHit(task, data);
            NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: isCachedResponse=%@ for taskIdentifier=%lu URL=%@",
                             cacheHit ? @"YES (NSURLCache)" : @"NO (network)",
                             (unsigned long)task.taskIdentifier,
                             task.originalRequest.URL.absoluteString);

            [timer stopTimer];

            if (error) {
                NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: noticing error domain=%@ code=%ld description=%@",
                                 error.domain, (long)error.code, error.localizedDescription);
                [NRMANSURLConnectionSupport noticeError:error
                                           forRequest:task.originalRequest
                                            withTimer:timer];
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: noticing response statusCode=%ld URL=%@ MIMEType=%@",
                                 [httpResponse isKindOfClass:[NSHTTPURLResponse class]] ? (long)httpResponse.statusCode : -1L,
                                 response.URL.absoluteString, response.MIMEType);
                [NRMANSURLConnectionSupport noticeResponse:response
                                              forRequest:task.originalRequest
                                               withTimer:timer
                                                 andBody:data
                                               bytesSent:(NSUInteger)task.countOfBytesSent
                                           bytesReceived:(NSUInteger)task.countOfBytesReceived];
            }
            // Set the timer corresponding with this task to nil since we just stopped it and recorded the network request.
            NRMA__setTimerForSessionTask(task, nil);
            NRMA__setDataForSessionTask(task, nil);
            NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: recording complete, timer and data cleared for taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
        } else {
            NRLOG_AGENT_DEBUG(@"[NSURLSession] recordTask: no timer found for taskIdentifier=%lu, skipping (task may have been instrumented before session or already recorded)", (unsigned long)task.taskIdentifier);
        }

    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                   class:@"NSURLSessionOverride"
                                selector:@"recordTask"];
    }
}

// Returns YES when both conditions hold:
//   1. countOfBytesReceived == 0 — no bytes arrived via the network transport layer
//   2. A valid NSURLCache entry existed for the URL when the task was created
// Together these are a reliable indicator that NSURLCache served the response.
// This works for URLSession.shared.dataTask(with:completionHandler:) even though
// that session has no delegate and never fires didFinishCollectingMetrics:.
BOOL NRMA__isURLCacheHit(NSURLSessionTask *task, NSData *data) {
    if (task == nil) return NO;

    // Primary signal: data was delivered but no bytes came from the network.
    // NSURLCache injects data directly; countOfBytesReceived only increments
    // for bytes that actually travel the transport layer.
    BOOL zeroBytesFromNetwork = (task.countOfBytesReceived == 0 && data.length > 0);

    // Corroborating signal: we saw a cached entry at task-creation time.
    // Prevents false positives from legitimate empty-body network responses (204, etc.).
    BOOL hadPreflightCacheHit = [objc_getAssociatedObject(task, kNRPreflightCacheHitKey) boolValue];

    NRLOG_AGENT_DEBUG(@"[NSURLSession] isURLCacheHit: taskIdentifier=%lu zeroBytesFromNetwork=%@ hadPreflightCacheHit=%@ → cacheHit=%@",
                     (unsigned long)task.taskIdentifier,
                     zeroBytesFromNetwork ? @"YES" : @"NO",
                     hadPreflightCacheHit ? @"YES" : @"NO",
                     (zeroBytesFromNetwork && hadPreflightCacheHit) ? @"YES" : @"NO");

    return hadPreflightCacheHit;//zeroBytesFromNetwork && hadPreflightCacheHit;
}

// ---------------------------------------------------------------------------

NRTimer* NRMA__getTimerForSessionTask(NSURLSessionTask* task)
{
    return objc_getAssociatedObject(task, kNRTimerAssociatedObject);
}

void NRMA__setTimerForSessionTask(NSURLSessionTask* task, NRTimer* timer)
{
    if (task == nil) return;

    objc_AssociationPolicy assocPolicy = OBJC_ASSOCIATION_RETAIN;
    if (timer == nil) {
        assocPolicy = OBJC_ASSOCIATION_ASSIGN;
    }
    objc_setAssociatedObject(task, kNRTimerAssociatedObject, timer, assocPolicy);
}

void NRMA__setDataForSessionTask(NSURLSessionTask* task, NSData* data)
{
    if (task == nil) return;

    objc_AssociationPolicy assocPolicy = OBJC_ASSOCIATION_RETAIN;
    if (data == nil) {
        assocPolicy = OBJC_ASSOCIATION_ASSIGN;
    }
    objc_setAssociatedObject(task, kNRSessionDataAssociatedObject, data, assocPolicy);
}

NSData* NRMA__getDataForSessionTask(NSURLSessionTask* task)
{
    if (task == nil) return nil;

    return objc_getAssociatedObject(task, kNRSessionDataAssociatedObject);
}
