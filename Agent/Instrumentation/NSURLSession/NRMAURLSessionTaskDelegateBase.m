//
//  NSURLSessionTaskDelegateBase.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/1/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionTaskDelegateBase_Private.h"
#import "NRMANSURLConnectionSupport+private.h"
#import "NRMAURLSessionTaskOverride.h"
#import "NRMAURLSessionOverride.h"
#import "NRMAExceptionHandler.h"
#import "NRLogger.h"

static NSString *NRMA__fetchTypeName(NSURLSessionTaskMetricsResourceFetchType type) {
    switch (type) {
        case NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad: return @"networkLoad";
        case NSURLSessionTaskMetricsResourceFetchTypeServerPush:  return @"serverPush";
        case NSURLSessionTaskMetricsResourceFetchTypeLocalCache:  return @"localCache";
        case NSURLSessionTaskMetricsResourceFetchTypeUnknown:
        default:                                                  return @"unknown";
    }
}

@implementation NRURLSessionTaskDelegateBase

- (instancetype) initWithOriginalDelegate:(id<NSURLSessionDataDelegate>)delegate
{
    self = [super init];
    if (self) {
        _realDelegate = delegate;
    }
    return self;
}

#pragma mark - NSURLSessionDataDelegate Methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if ([self.realDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [self.realDelegate URLSession:session
                             dataTask:dataTask
                   didReceiveResponse:response completionHandler:completionHandler];
    }
    else if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    @try {
        NRTimer* timer = NRMA__getTimerForSessionTask(task);
        // If timer is nil then maybe we didn't instrument the task in time, let's not record it.
        if (timer) {

            [timer stopTimer];

            if (error) {
                [NRMANSURLConnectionSupport noticeError:error
                                             forRequest:task.originalRequest
                                              withTimer:timer];
            } else {
                NSData *data = NRMA__getDataForSessionTask(task);
                NSString* fetchType = NRMA__getFetchTypeForSessionTask(task);
                NSInteger wireStatus = NRMA__getWireStatusForSessionTask(task);
                int64_t wireBytes = NRMA__getWireBytesForSessionTask(task);

                [NRMANSURLConnectionSupport noticeResponse:task.response
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

    } @catch(NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:@"URLSession:task:didCompleteWithError:"];
    }
    
    if ([self.realDelegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [self.realDelegate URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NRMA__setDataForSessionTask(dataTask, data);
    if ([self.realDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [self.realDelegate URLSession:session
                             dataTask:dataTask
                       didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    @try {
        NSURLSessionTaskTransactionMetrics *last = metrics.transactionMetrics.lastObject;
        NSInteger appVisibleStatus = [task.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)task.response statusCode] : -1;
        NSInteger finalWireStatus  = [last.response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)last.response statusCode] : -1;

        // Stash on the task so didCompleteWithError: can attach them to the MobileRequest event.
        NRMA__setFetchTypeForSessionTask(task, NRMA__fetchTypeName(last.resourceFetchType));
        if (finalWireStatus > 0) {
            NRMA__setWireStatusForSessionTask(task, finalWireStatus);
        }
        if (last.countOfResponseBodyBytesReceived > 0) {
            NRMA__setWireBytesForSessionTask(task, last.countOfResponseBodyBytesReceived);
        }

        NRLOG_AGENT_INFO(@"[NRFetch] url=%@ txCount=%lu finalFetchType=%@(%ld) "
                         @"finalWireStatus=%ld appVisibleStatus=%ld reusedConn=%d proxy=%d",
                         task.originalRequest.URL.absoluteString,
                         (unsigned long)metrics.transactionMetrics.count,
                         NRMA__fetchTypeName(last.resourceFetchType),
                         (long)last.resourceFetchType,
                         (long)finalWireStatus,
                         (long)appVisibleStatus,
                         last.reusedConnection,
                         last.proxyConnection);

        NSUInteger i = 0;
        for (NSURLSessionTaskTransactionMetrics *t in metrics.transactionMetrics) {
            NSInteger wireStatus = [t.response isKindOfClass:[NSHTTPURLResponse class]]
                ? [(NSHTTPURLResponse *)t.response statusCode] : -1;
            NRLOG_AGENT_INFO(@"[NRFetch.tx %lu] fetchType=%@(%ld) wireStatus=%ld reusedConn=%d",
                             (unsigned long)i,
                             NRMA__fetchTypeName(t.resourceFetchType),
                             (long)t.resourceFetchType,
                             (long)wireStatus,
                             t.reusedConnection);
            i++;
        }
    } @catch (NSException *exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:@"URLSession:task:didFinishCollectingMetrics:"];
    }

    if ([self.realDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [(id<NSURLSessionTaskDelegate>)self.realDelegate URLSession:session
                                                              task:task
                                       didFinishCollectingMetrics:metrics];
    }
}

@end

