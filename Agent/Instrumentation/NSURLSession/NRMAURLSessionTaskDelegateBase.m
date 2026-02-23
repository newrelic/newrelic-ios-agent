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
    NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didReceiveResponse: taskIdentifier=%lu URL=%@ MIMEType=%@ expectedContentLength=%lld",
                     (unsigned long)dataTask.taskIdentifier, response.URL.absoluteString,
                     response.MIMEType ?: @"nil", response.expectedContentLength);
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didReceiveResponse: HTTP statusCode=%ld", (long)httpResponse.statusCode);
    }
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
    NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: taskIdentifier=%lu URL=%@ error=%@",
                     (unsigned long)task.taskIdentifier,
                     task.originalRequest.URL.absoluteString ?: @"nil",
                     error ?: @"nil");
    @try {
        NRTimer* timer = NRMA__getTimerForSessionTask(task);
        // If timer is nil then maybe we didn't instrument the task in time, let's not record it.
        if (timer) {
            NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: timer present elapsed=%.3fs bytesSent=%lld bytesReceived=%lld",
                             timer.timeElapsedInSeconds, task.countOfBytesSent, task.countOfBytesReceived);
            NSData *dataForCacheCheck = NRMA__getDataForSessionTask(task);
            BOOL cacheHit = NRMA__isURLCacheHit(task, dataForCacheCheck);
            NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: isCachedResponse=%@ for taskIdentifier=%lu URL=%@",
                             cacheHit ? @"YES (NSURLCache)" : @"NO (network)",
                             (unsigned long)task.taskIdentifier,
                             task.originalRequest.URL.absoluteString ?: @"nil");

            [timer stopTimer];

            if (error) {
                NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: noticing error domain=%@ code=%ld",
                                 error.domain, (long)error.code);
                [NRMANSURLConnectionSupport noticeError:error
                                             forRequest:task.originalRequest
                                              withTimer:timer];
            } else {
                NSData *data = NRMA__getDataForSessionTask(task);
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
                NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: noticing response statusCode=%ld dataBodyLength=%lu",
                                 [httpResponse isKindOfClass:[NSHTTPURLResponse class]] ? (long)httpResponse.statusCode : -1L,
                                 (unsigned long)data.length);

                [NRMANSURLConnectionSupport noticeResponse:task.response
                                                forRequest:task.originalRequest
                                                 withTimer:timer
                                                   andBody:data
                                                 bytesSent:(NSUInteger)task.countOfBytesSent
                                             bytesReceived:(NSUInteger)task.countOfBytesReceived];
            }
            // Set the timer corresponding with this task to nil since we just stopped it and recorded the network request.
            NRMA__setTimerForSessionTask(task, nil);
            NRMA__setDataForSessionTask(task, nil);
            NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: recording complete, timer and data cleared for taskIdentifier=%lu", (unsigned long)task.taskIdentifier);
        } else {
            NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didCompleteWithError: no timer for taskIdentifier=%lu, skipping recording", (unsigned long)task.taskIdentifier);
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
    NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didReceiveData: taskIdentifier=%lu dataLength=%lu",
                     (unsigned long)dataTask.taskIdentifier, (unsigned long)data.length);
    NRMA__setDataForSessionTask(dataTask, data);
    if ([self.realDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [self.realDelegate URLSession:session
                             dataTask:dataTask
                       didReceiveData:data];
    }
}

// URLSessionTaskMetrics cache detection:
// NSURLSessionTaskTransactionMetrics.resourceFetchType reveals whether a request
// was served from the local cache (NSURLSessionTaskMetricsResourceFetchTypeLocalCache),
// from the network (NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad),
// or via HTTP/2 server push (NSURLSessionTaskMetricsResourceFetchTypeServerPush).
// This delegate method fires after every task completes, including cached ones —
// even when no actual network connection was made.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)) {
    NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didFinishCollectingMetrics: taskIdentifier=%lu URL=%@ transactionCount=%lu taskInterval=%.3fs",
                     (unsigned long)task.taskIdentifier,
                     task.originalRequest.URL.absoluteString ?: @"nil",
                     (unsigned long)metrics.transactionMetrics.count,
                     metrics.taskInterval.duration);

    BOOL isCachedRequest = NO;

    for (NSURLSessionTaskTransactionMetrics *txMetrics in metrics.transactionMetrics) {
        NSString *fetchTypeLabel = @"Unknown";
        switch (txMetrics.resourceFetchType) {
            case NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad:
                fetchTypeLabel = @"NetworkLoad";
                break;
            case NSURLSessionTaskMetricsResourceFetchTypeServerPush:
                fetchTypeLabel = @"ServerPush";
                break;
            case NSURLSessionTaskMetricsResourceFetchTypeLocalCache:
                fetchTypeLabel = @"LocalCache";
                isCachedRequest = YES;
                break;
            default:
                fetchTypeLabel = @"Unknown";
                break;
        }

        NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] metrics transaction: fetchType=%@ protocol=%@ proxy=%@ reusedConn=%@ URL=%@",
                         fetchTypeLabel,
                         txMetrics.networkProtocolName ?: @"nil",
                         txMetrics.proxyConnection ? @"YES" : @"NO",
                         txMetrics.reusedConnection ? @"YES" : @"NO",
                         txMetrics.request.URL.absoluteString ?: @"nil");

        if (txMetrics.fetchStartDate) {
            NSTimeInterval responseLatency = txMetrics.responseStartDate && txMetrics.requestEndDate
                ? [txMetrics.responseStartDate timeIntervalSinceDate:txMetrics.requestEndDate]
                : -1;
            NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] metrics timing: fetchStart=%@ domainLookup=%@ connect=%@ TLS=%@ request=%@ responseLatency=%.3fs",
                             txMetrics.fetchStartDate,
                             (txMetrics.domainLookupStartDate && txMetrics.domainLookupEndDate)
                                 ? [NSString stringWithFormat:@"%.3fs", [txMetrics.domainLookupEndDate timeIntervalSinceDate:txMetrics.domainLookupStartDate]]
                                 : @"n/a",
                             (txMetrics.connectStartDate && txMetrics.connectEndDate)
                                 ? [NSString stringWithFormat:@"%.3fs", [txMetrics.connectEndDate timeIntervalSinceDate:txMetrics.connectStartDate]]
                                 : @"n/a",
                             (txMetrics.secureConnectionStartDate && txMetrics.secureConnectionEndDate)
                                 ? [NSString stringWithFormat:@"%.3fs", [txMetrics.secureConnectionEndDate timeIntervalSinceDate:txMetrics.secureConnectionStartDate]]
                                 : @"n/a",
                             (txMetrics.requestStartDate && txMetrics.requestEndDate)
                                 ? [NSString stringWithFormat:@"%.3fs", [txMetrics.requestEndDate timeIntervalSinceDate:txMetrics.requestStartDate]]
                                 : @"n/a",
                             responseLatency);
        }
    }

    NRLOG_AGENT_DEBUG(@"[NSURLSessionDelegate] didFinishCollectingMetrics: taskIdentifier=%lu isCachedRequest=%@",
                     (unsigned long)task.taskIdentifier, isCachedRequest ? @"YES" : @"NO");

    if ([self.realDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [self.realDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}

@end

