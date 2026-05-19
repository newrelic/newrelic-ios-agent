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
#import "NRLogger.h"

#define NRMASwizzledMethodPrefix @"_NRMAOverride__"

// Phase-2 viability probe: try to read private NSURLSessionTaskMetrics on tasks
// that have NO delegate (URLSession.shared completion-handler path, async/await path).
// Diagnostic-only; never ship enabled.
#define NR_DEBUG_FETCH_TYPE_PROBE 1

#if NR_DEBUG_FETCH_TYPE_PROBE
static NSString *NRMA__probeFetchTypeName(NSInteger type) {
    switch (type) {
        case 0: return @"unknown";
        case 1: return @"networkLoad";
        case 2: return @"serverPush";
        case 3: return @"localCache";
        default: return @"?";
    }
}

static void NRMA__probeTaskMetrics(NSURLSessionTask *task, NSString *origin) {
    @try {
        // _metrics is private SPI on NSURLSessionTask. KVC peek — diagnostic only.
        NSURLSessionTaskMetrics *m = nil;
        @try { m = [task valueForKey:@"_metrics"]; } @catch (...) {}
        if (m == nil) {
            @try { m = [task valueForKey:@"metrics"]; } @catch (...) {}
        }
        if (m == nil) {
            NRLOG_AGENT_INFO(@"[NRFetchProbe %@] url=%@ metrics=nil",
                             origin, task.originalRequest.URL.absoluteString);
            return;
        }
        NSURLSessionTaskTransactionMetrics *last = m.transactionMetrics.lastObject;
        NSInteger appVisibleStatus = [task.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)task.response statusCode] : -1;
        NSInteger wireStatus = [last.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)last.response statusCode] : -1;
        NRLOG_AGENT_INFO(@"[NRFetchProbe %@] url=%@ txCount=%lu finalFetchType=%@(%ld) "
                         @"finalWireStatus=%ld appVisibleStatus=%ld",
                         origin,
                         task.originalRequest.URL.absoluteString,
                         (unsigned long)m.transactionMetrics.count,
                         NRMA__probeFetchTypeName(last.resourceFetchType),
                         (long)last.resourceFetchType,
                         (long)wireStatus,
                         (long)appVisibleStatus);
    } @catch (NSException *e) {
        NRLOG_AGENT_INFO(@"[NRFetchProbe %@] exception: %@", origin, e);
    }
}
#endif

IMP NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue;
IMP NRMAOriginal__sessionWithConfiguration;
IMP NRMAOriginal__sharedSession;

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

@interface PayloadHolder : NSObject
@property (nonatomic, retain) NRMAPayload *objcPayload;
@property (nonatomic, retain) NRMAPayloadContainer *cppPayload;
@end

@implementation PayloadHolder
@end

#pragma mark - Metrics-only injected delegate

// Lightweight session delegate injected when the customer didn't supply one
// (URLSession.shared and URLSession(configuration:)) so we can capture
// resourceFetchType / wireStatusCode from didFinishCollectingMetrics:.
// Also implements didReceiveData: so the agent can capture the response body
// for async/await calls on URLSession.shared (which otherwise has no public
// hook for body bytes). didCompleteWithError: is deliberately NOT implemented
// so customer completion handlers continue to receive bytes from Apple's
// internal data path unchanged.
@interface NRMAURLSessionMetricsOnlyDelegate : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@end

static NSString *NRMA__injectedFetchTypeName(NSURLSessionTaskMetricsResourceFetchType type) {
    switch (type) {
        case NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad: return @"networkLoad";
        case NSURLSessionTaskMetricsResourceFetchTypeServerPush:  return @"serverPush";
        case NSURLSessionTaskMetricsResourceFetchTypeLocalCache:  return @"localCache";
        case NSURLSessionTaskMetricsResourceFetchTypeUnknown:
        default:                                                  return @"unknown";
    }
}

@implementation NRMAURLSessionMetricsOnlyDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    if (data.length == 0) return;
    @try {
        NSData *existing = NRMA__getDataForSessionTask(dataTask);
        if (existing.length > 0) {
            NSMutableData *combined = [NSMutableData dataWithCapacity:existing.length + data.length];
            [combined appendData:existing];
            [combined appendData:data];
            NRMA__setDataForSessionTask(dataTask, combined);
        } else {
            NRMA__setDataForSessionTask(dataTask, data);
        }
    } @catch (NSException *e) {
        [NRMAExceptionHandler logException:e
                                     class:NSStringFromClass([self class])
                                  selector:@"URLSession:dataTask:didReceiveData:"];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    @try {
        NSURLSessionTaskTransactionMetrics *last = metrics.transactionMetrics.lastObject;
        NRMA__setFetchTypeForSessionTask(task, NRMA__injectedFetchTypeName(last.resourceFetchType));
        NSInteger wire = [last.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)last.response statusCode] : 0;
        if (wire > 0) {
            NRMA__setWireStatusForSessionTask(task, wire);
        }
        if (last.countOfResponseBodyBytesReceived > 0) {
            NRMA__setWireBytesForSessionTask(task, last.countOfResponseBodyBytesReceived);
        }
    } @catch (NSException *e) {
        [NRMAExceptionHandler logException:e
                                     class:NSStringFromClass([self class])
                                  selector:@"URLSession:task:didFinishCollectingMetrics:"];
    }
}

@end

// Lazily-constructed session that the +sharedSession swizzle hands out. Built
// directly via the original IMP so our wrap-the-delegate swizzle on
// sessionWithConfiguration:delegate:delegateQueue: doesn't double-wrap.
static NSURLSession *NRMA__injectedSharedSession(void) {
    static NSURLSession *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue == nil) return;
        NRMAURLSessionMetricsOnlyDelegate *delegate = [NRMAURLSessionMetricsOnlyDelegate new];
        Class sessionClass = objc_getClass("NSURLSession");
        SEL sel = @selector(sessionWithConfiguration:delegate:delegateQueue:);
        sharedInstance = ((id(*)(id, SEL, id, id, id))NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue)(
            sessionClass, sel,
            [NSURLSessionConfiguration defaultSessionConfiguration],
            delegate,
            nil);
    });
    return sharedInstance;
}

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
    id clazz = objc_getClass("NSURLSession");
    if (clazz) {
        //session task overrides
        NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue = NRMASwapImplementations(clazz,@selector(sessionWithConfiguration:delegate:delegateQueue:), (IMP)NRMAOverride__sessionWithConfiguration_delegate_delegateQueue);

        /*
         * In iOS 13 the definition of NSURLSession changed under the hood, and the way we instrument these methods has changed. iOS 13 specific requirements are wrapped in a @available.
         */
        if (@available(iOS 13, *)) {
            id obj = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            id concreteClass = [obj class];
            clazz = concreteClass;
        }
        // Data Task  method overrides
        NRMAOriginal__dataTaskWithRequest = NRMASwapImplementations(clazz, @selector(dataTaskWithRequest:), (IMP)NRMAOverride__dataTaskWithRequest);
        
        NRMAOriginal__dataTaskWithURL = NRMASwapImplementations(clazz, @selector(dataTaskWithURL:), (IMP)NRMAOverride__dataTaskWithURL);

        if (@available(iOS 13, *)) { //in os prior to 13 dataTaskWithURL would call dataTaskWithRequest in turn. This is no longer the case, and must be instrumented explicitly.
            NRMAOriginal__dataTaskWithURL_completionHandler = NRMASwapImplementations(clazz, @selector(dataTaskWithURL:completionHandler:), (IMP) NRMAOverride__dataTaskWithURL_completionHandler);
        }
        
        NRMAOriginal__dataTaskWithRequest_completionHandler = NRMASwapImplementations(clazz, @selector(dataTaskWithRequest:completionHandler:), (IMP)NRMAOverride__dataTaskWithRequest_completionHandler);
        
        //upload tasks method overrides
        NRMAOriginal__uploadTaskWithRequest_fromData = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromData:), (IMP)NRMAOverride__uploadTaskWithRequest_fromData);
        
        NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromData:completionHandler:), (IMP)NRMAOverride__uploadTaskWithRequest_fromData_completionHandler);

        NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromFile:completionHandler:), (IMP)NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler);
        
        NRMAOriginal__uploadTaskWithRequest_fromFile = NRMASwapImplementations(clazz, @selector(uploadTaskWithRequest:fromFile:), (IMP)NRMAOverride__uploadTaskWithRequest_fromFile);
        
        NRMAOriginal__uploadTaskWithStreamedRequest=NRMASwapImplementations(clazz,@selector(uploadTaskWithStreamedRequest:),(IMP)NRMAOverride__uploadTaskWithStreamedRequest);
    }
    
    if ([NRMAFlags shouldEnableSwiftAsyncURLSessionSupport]) {
        [self swizzleURLSessionTask];
    }

    if ([NRMAFlags shouldEnableURLSessionDelegateInjection]) {
        Class baseSessionClass = objc_getClass("NSURLSession");
        if (baseSessionClass) {
            // Class methods live on the metaclass.
            NRMAOriginal__sessionWithConfiguration = NRMASwapImplementations(baseSessionClass,
                                                                             @selector(sessionWithConfiguration:),
                                                                             (IMP)NRMAOverride__sessionWithConfiguration);
            NRMAOriginal__sharedSession = NRMASwapImplementations(baseSessionClass,
                                                                  @selector(sharedSession),
                                                                  (IMP)NRMAOverride__sharedSession);
        }
    }
}

+ (void) deinstrument
{
    id clazz = objc_getClass("NSURLSession");
    if (clazz) {
        // Reverse the delegate-injection swizzles first, before the metaclass shifts.
        if (NRMAOriginal__sessionWithConfiguration != nil) {
            NRMASwapImplementations(clazz, @selector(sessionWithConfiguration:), (IMP)NRMAOriginal__sessionWithConfiguration);
            NRMAOriginal__sessionWithConfiguration = nil;
        }
        if (NRMAOriginal__sharedSession != nil) {
            NRMASwapImplementations(clazz, @selector(sharedSession), (IMP)NRMAOriginal__sharedSession);
            NRMAOriginal__sharedSession = nil;
        }

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
    for (Class classToSwizzle in classesToSwizzle) {
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
    id wrappedDelegate = nil;
    if (delegate != nil) {
        // Don't wrap our own injected delegate.
        if ([delegate isKindOfClass:[NRMAURLSessionMetricsOnlyDelegate class]]) {
            wrappedDelegate = delegate;
        } else {
            wrappedDelegate = [[NRMAURLSessionTaskDelegate alloc] initWithOriginalDelegate:delegate];
        }
    } else if ([NRMAFlags shouldEnableURLSessionDelegateInjection]) {
        wrappedDelegate = [NRMAURLSessionMetricsOnlyDelegate new];
    }

    NSURLSession* session = ((id(*)(id, SEL, id, id, id))NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue)(self,
                                                                                         _cmd,
                                                                                         configuration,
                                                                                         wrappedDelegate,
                                                                                         queue);
    return session;
}

NSURLSession* NRMAOverride__sessionWithConfiguration(id self, SEL _cmd, NSURLSessionConfiguration* configuration)
{
    if (NRMAOriginal__sessionWithConfiguration == nil) {
        return nil;
    }

    if (![NRMAFlags shouldEnableURLSessionDelegateInjection]) {
        return ((id(*)(id, SEL, id))NRMAOriginal__sessionWithConfiguration)(self, _cmd, configuration);
    }

    // Inject our metrics-only delegate by routing through the original
    // sessionWithConfiguration:delegate:delegateQueue: IMP — bypassing our
    // wrap-the-delegate swizzle so the delegate isn't double-wrapped.
    if (NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue == nil) {
        return ((id(*)(id, SEL, id))NRMAOriginal__sessionWithConfiguration)(self, _cmd, configuration);
    }

    NRMAURLSessionMetricsOnlyDelegate *delegate = [NRMAURLSessionMetricsOnlyDelegate new];
    SEL fullSel = @selector(sessionWithConfiguration:delegate:delegateQueue:);
    return ((id(*)(id, SEL, id, id, id))NRMAOriginal__sessionWithConfiguration_delegate_delegateQueue)(self,
                                                                                                       fullSel,
                                                                                                       configuration,
                                                                                                       delegate,
                                                                                                       nil);
}

NSURLSession* NRMAOverride__sharedSession(id self, SEL _cmd)
{
    if (![NRMAFlags shouldEnableURLSessionDelegateInjection]) {
        if (NRMAOriginal__sharedSession == nil) return nil;
        return ((id(*)(id, SEL))NRMAOriginal__sharedSession)(self, _cmd);
    }

    NSURLSession *injected = NRMA__injectedSharedSession();
    if (injected != nil) return injected;

    // Fall back to original if injection couldn't build a session.
    if (NRMAOriginal__sharedSession == nil) return nil;
    return ((id(*)(id, SEL))NRMAOriginal__sharedSession)(self, _cmd);
}


#pragma mark - NSURLSessionDataTask overrides

NSURLSessionTask* NRMAOverride__dataTaskWithRequest(id self, SEL _cmd, NSURLRequest* request)
{
    if (self == nil) {
        return nil;
    }
    if (_cmd == nil) {
        return nil;
    }
    if (request == nil) {
        return nil;
    }
    if (NRMAOriginal__dataTaskWithRequest == nil) {
        return nil;
    }
    
    if (request.URL == nil) {
        return nil;
    } else {
    }
    
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
    
    if([NRMAFlags shouldEnableNewEventSystem]){
        [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload
                                      to:task.originalRequest];
    } else {
        [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload
                                      to:task.originalRequest];
    }

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
            
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
        return nil;
    }

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    __block NSURLSessionTask* task = nil;
    
    PayloadHolder *payloadHolder = [[PayloadHolder alloc] init];
    if([NRMAFlags shouldEnableNewEventSystem]) {
        payloadHolder.objcPayload = ([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest]);
    } else {
        payloadHolder.cppPayload = ([NRMAHTTPUtilities addConnectivityHeader:mutableRequest]);
    }
    
    if (completionHandler == nil) {
        task  = ((id(*)(id,SEL,NSURLRequest*,void(^)(NSData*,NSURLResponse*,NSError*)))originalImp)(self,_cmd,mutableRequest,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }
        
        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
        return task;
    }
    
    task =  ((id(*)(id,SEL,NSURLRequest*,void(^)(NSData*,NSURLResponse*,NSError*)))originalImp)(self,_cmd,mutableRequest,^(NSData* data, NSURLResponse* response, NSError* error){

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }
        
        // NRLOG_AGENT_VERBOSE(@"NRMA__recordTask called from NRMAOverride__dataTaskWithRequest_completionHandler");

        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];

    return task;
}

NSURLSessionTask* NRMAOverride__dataTaskWithURL(id self, SEL _cmd, NSURL* url)
{
    IMP originalImp = NRMAOriginal__dataTaskWithURL;

    if (originalImp == nil) {
        return nil;
    }

    NSURLSessionTask* task = ((id(*)(id,SEL,NSURL*))originalImp)(self,_cmd,url);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    return task;
}

#pragma mark - NSURLSessionUploadTask Overrides

NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromFile(id self, SEL _cmd, NSURLRequest* request, NSURL* fileURL)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithRequest_fromFile;

    if (originalImp == nil) {
        return nil;
    }

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

    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    
    return task;
}

NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromData(id self, SEL _cmd, NSURLRequest* request, NSData* data)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithRequest_fromData;

    if (originalImp == nil) {
        return nil;
    }

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

    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    
    return task;
}

NSURLSessionTask* NRMAOverride__uploadTaskWithStreamedRequest(id self, SEL _cmd, NSURLRequest* request)
{
    IMP originalImp = (IMP)NRMAOriginal__uploadTaskWithStreamedRequest;

    if (originalImp == nil) {

        return nil;
    }

    NSURLSessionTask* task = ((NSURLSessionTask*(*)(id,SEL,NSURLRequest*))originalImp)(self, _cmd,request);
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    
    return task;
}

NSURLSessionUploadTask* NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSURL* fileURL, void (^completionHandler)(NSData*,NSURLResponse*,NSError*))
{
    IMP originalIMP = NRMAOriginal__uploadTaskWithRequest_fromFile_completionHandler;

    if (originalIMP == nil) {

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
        task = ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSURL*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,fileURL,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }
    
        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
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
        
        //  NSLog(@"NRMA__recordTask called from NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler");

        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    return task;
    
}

NSURLSessionUploadTask* NRMAOverride__uploadTaskWithRequest_fromData_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSData* bodyData, void (^completionHandler)(NSData*,NSURLResponse*,NSError*))
{
    IMP originalIMP = NRMAOriginal__uploadTaskWithRequest_fromData_completionHandler;

    if (originalIMP == nil) {

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
        task = ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSData*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,bodyData,completionHandler);
        objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }

        [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
        return task;
    }
    
    task =  ((NSURLSessionUploadTask*(*)(id,SEL,NSURLRequest*,NSData*,void(^)(NSData*,NSURLResponse*,NSError*)))originalIMP)(self,_cmd,mutableRequest,bodyData,^(NSData* data, NSURLResponse* response, NSError* error){

        if([NRMAFlags shouldEnableNewEventSystem]) {
            [NRMAHTTPUtilities attachNRMAPayload:payloadHolder.objcPayload to:task.originalRequest];
        } else {
            [NRMAHTTPUtilities attachPayload:payloadHolder.cppPayload to:task.originalRequest];
        }
        
        NRMA__recordTask(task,data,response,error);

        completionHandler(data,response,error);
    });
    objc_setAssociatedObject(task, NRMAHandledRequestKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Try to override the methods of the private class that is returned by this method.
    [NRMAURLSessionTaskOverride instrumentConcreteClass:[task class]];
    return task;
}

void NRMA__recordTask(NSURLSessionTask* task, NSData* data, NSURLResponse* response, NSError* error)
{
#if NR_DEBUG_FETCH_TYPE_PROBE
    NRMA__probeTaskMetrics(task, @"recordTask");
#endif
    @try {
        NRTimer* timer = NRMA__getTimerForSessionTask(task);
        // If there is no timer, let's not record this network activity. this could mean a session executed before task was instrumented or the request has already been instrumented by another handler.
        if (timer) {

            [timer stopTimer];

            NSString* fetchType = NRMA__getFetchTypeForSessionTask(task);
            NSInteger wireStatus = NRMA__getWireStatusForSessionTask(task);
            int64_t wireBytes = NRMA__getWireBytesForSessionTask(task);

            if (error) {
                [NRMANSURLConnectionSupport noticeError:error
                                           forRequest:task.originalRequest
                                            withTimer:timer];
            } else {
                [NRMANSURLConnectionSupport noticeResponse:response
                                              forRequest:task.originalRequest
                                               withTimer:timer
                                                 andBody:data
                                               bytesSent:(NSUInteger)task.countOfBytesSent
                                           bytesReceived:(NSUInteger)task.countOfBytesReceived
                                       resourceFetchType:fetchType
                                          wireStatusCode:wireStatus
                                       wireBytesReceived:wireBytes];
            }
            // Set the timer corresponding with this task to nil since we just stopped it and recorded the network request.
            NRMA__setTimerForSessionTask(task, nil);
            NRMA__setDataForSessionTask(task, nil);
            NRMA__setFetchTypeForSessionTask(task, nil);
        }

    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                   class:@"NSURLSessionOverride"
                                selector:@"recordTask"];
    }
}

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

NSString* NRMA__getFetchTypeForSessionTask(NSURLSessionTask* task)
{
    if (task == nil) return nil;
    return objc_getAssociatedObject(task, kNRFetchTypeAssociatedObject);
}

void NRMA__setFetchTypeForSessionTask(NSURLSessionTask* task, NSString* fetchType)
{
    if (task == nil) return;
    objc_AssociationPolicy policy = fetchType ? OBJC_ASSOCIATION_RETAIN_NONATOMIC : OBJC_ASSOCIATION_ASSIGN;
    objc_setAssociatedObject(task, kNRFetchTypeAssociatedObject, fetchType, policy);
}

NSInteger NRMA__getWireStatusForSessionTask(NSURLSessionTask* task)
{
    if (task == nil) return 0;
    NSNumber* val = objc_getAssociatedObject(task, kNRWireStatusAssociatedObject);
    return val ? [val integerValue] : 0;
}

void NRMA__setWireStatusForSessionTask(NSURLSessionTask* task, NSInteger wireStatus)
{
    if (task == nil) return;
    objc_setAssociatedObject(task, kNRWireStatusAssociatedObject, @(wireStatus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

int64_t NRMA__getWireBytesForSessionTask(NSURLSessionTask* task)
{
    if (task == nil) return 0;
    NSNumber* val = objc_getAssociatedObject(task, kNRWireBytesAssociatedObject);
    return val ? [val longLongValue] : 0;
}

void NRMA__setWireBytesForSessionTask(NSURLSessionTask* task, int64_t wireBytes)
{
    if (task == nil) return;
    objc_setAssociatedObject(task, kNRWireBytesAssociatedObject, @(wireBytes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
