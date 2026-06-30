//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
#import "NRMARetryTracker.h"
#import "NRLogger.h"
#include <libkern/OSAtomic.h>
#import "NRMASupportMetricHelper.h"
#import "NRConstants.h"
#import "NewRelicInternalUtils.h"
#import "NRMAReachability.h"
#import "NRMAOfflineStorage.h"
#import "NRMAFlags.h"

#define kNRMARetryLimit 2 // this will result in 2 additional upload attempts.

// Bound how many uploads we hold in flight. Under low-bandwidth a default
// session will queue tasks indefinitely; each task holds a socket FD until
// the request completes or times out, exhausting the per-process FD limit.
static const NSUInteger kNRMAHexMaxInFlight = 4;

// Hard cap on the in-memory pending queue so a permanently-offline app
// cannot grow RAM unboundedly when the caller keeps submitting reports.
static const NSUInteger kNRMAHexMaxPending = 50;

// Tighter than NSURLSession defaults (60s). Under low-bandwidth, the default
// keeps sockets alive for a full minute per task — combined with concurrent
// retries, that's how the customer hits "Too many open files".
static const NSTimeInterval kNRMAHexRequestTimeout = 30.0;

@interface NRMAHexUploader()
@property(strong) NSString* host;
@property(strong) NSMutableArray* retryQueue;
@property(strong) NSURLSession* session;
@property(strong) NRMARetryTracker* taskStore;

// Concurrency control — guarded by @synchronized(self).
@property(strong) NSMutableArray<NSData*>* pendingPayloads;
@property(assign) NSUInteger inFlightCount;

// Tracks the upload payload for each in-flight / retryable request, keyed
// by content-equal NSURLRequest. NSURLSessionUploadTask requires the payload
// to come from `fromData:` (not from the request's HTTPBody — iOS warns and
// strips it), so we cannot stash bytes on the request itself. This dictionary
// is the parallel store that lets handledErroredRequest: rebuild the upload
// with the original payload. Guarded by @synchronized(_payloadByRequest).
@property(strong) NSMutableDictionary<NSURLRequest*, NSData*>* payloadByRequest;

// Disk-backed retry for uploads that fail because the device is offline (or hit a
// persist-worthy network error). Mirrors SessionReplayReporter / NRMAHarvesterConnection:
// persist the payload on a network-error failure, then drain + re-send on a later
// successful upload. Only used when [NRMAFlags shouldEnableOfflineStorage] is on.
@property(strong) NRMAOfflineStorage* offlineStorage;
@end

@implementation NRMAHexUploader

- (instancetype) initWithHost:(NSString*)host {
    self = [super init];
    if (self) {
        self.host = host;
        self.retryQueue = [NSMutableArray new];
        self.pendingPayloads = [NSMutableArray new];
        self.payloadByRequest = [NSMutableDictionary new];
        self.inFlightCount = 0;
        // initWithEndpoint: seeds the cap from [NRMAAgentConfiguration getMaxOfflineStorageSize]
        // (bytes); do not call setMaxOfflineStorageSize: (it expects MB and would re-scale).
        self.offlineStorage = [[NRMAOfflineStorage alloc] initWithEndpoint:@"hex"];

        NSURLSessionConfiguration* cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.HTTPMaximumConnectionsPerHost = kNRMAHexMaxInFlight;
        cfg.timeoutIntervalForRequest = kNRMAHexRequestTimeout;
        self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
        self.taskStore = [[NRMARetryTracker alloc] initWithRetryLimit:kNRMARetryLimit];
    }
    return self;
}

+ (instancetype) sharedUploaderWithHost:(NSString*)host
                       applicationToken:(NSString*)applicationToken
                     applicationVersion:(NSString*)applicationVersion {
    static NRMAHexUploader* shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[NRMAHexUploader alloc] initWithHost:host];
    });
    @synchronized(shared) {
        if (host) shared.host = host;
        if (applicationToken) shared.applicationToken = applicationToken;
        if (applicationVersion) shared.applicationVersion = applicationVersion;
    }
    return shared;
}


- (void) sendData:(NSData*)data {
    if (data == nil) return;

    if ([data length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"Hex uploader handled exceptions payload is greater than 1 MB, discarding payload");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"f"];
        return;
    }

    @synchronized(self) {
        // Drop oldest first if pending grows beyond the soft cap. This is the
        // memory-spike guard the customer reported — under permanent offline
        // we'd otherwise hold every report in RAM forever.
        while (self.pendingPayloads.count >= kNRMAHexMaxPending) {
            [self.pendingPayloads removeObjectAtIndex:0];
            NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - dropping oldest pending payload, queue full");
        }
        [self.pendingPayloads addObject:data];
    }
    [self drainPending];
}

// Caller must NOT hold @synchronized(self) when invoking. Drains as many
// pending payloads as the in-flight cap allows; reentrant-safe.
- (void) drainPending {
    NSMutableArray<NSData*>* toSend = nil;
    @synchronized(self) {
        while (self.inFlightCount < kNRMAHexMaxInFlight && self.pendingPayloads.count > 0) {
            if (toSend == nil) toSend = [NSMutableArray new];
            [toSend addObject:self.pendingPayloads.firstObject];
            [self.pendingPayloads removeObjectAtIndex:0];
            self.inFlightCount++;
        }
    }
    for (NSData* data in toSend) {
        [self launchUpload:data];
    }
}

- (void) launchUpload:(NSData*)data {
    NSMutableURLRequest* request = [self newPostWithURI:self.host];
    if (request == nil) {
        @synchronized(self) {
            if (self.inFlightCount > 0) self.inFlightCount--;
        }
        return;
    }

    request.HTTPMethod = @"POST";
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];

    NSURLSessionUploadTask* uploadTask = [self uploadTaskForRequest:request data:data];
    if (uploadTask == nil) {
        @synchronized(self) {
            if (self.inFlightCount > 0) self.inFlightCount--;
        }
        return;
    }
    NSURLRequest* key = uploadTask.originalRequest ?: request;

    @synchronized(self.payloadByRequest) {
        self.payloadByRequest[key] = data;
    }
    [self.taskStore track:key];
    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload started: %@", request);
    [uploadTask resume];
}

- (NSURLSessionUploadTask*) uploadTaskForRequest:(NSURLRequest*)request data:(NSData*)data {
    return [self.session uploadTaskWithRequest:request fromData:data];
}

- (void) retryFailedTasks {
    NSArray* localRetryQueue;
    @synchronized(self.retryQueue) {
        localRetryQueue = self.retryQueue;
        // Prevent this temp local from being optimized out.
        OSMemoryBarrier();
        self.retryQueue = [NSMutableArray new];
    }

    for (NSURLSessionUploadTask* task in localRetryQueue) {
        [task resume];
    }
}

- (void) invalidate {
    [self.session finishTasksAndInvalidate];
}

- (void) dealloc {
    [self.session finishTasksAndInvalidate];
}

- (void)  URLSession:(NSURLSession*)session
                task:(NSURLSessionTask*)task
didCompleteWithError:(nullable NSError*)error {

    if (error) {
#if !TARGET_OS_WATCH
        if (error.code == kCFURLErrorCancelled) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - Handled exception upload cancelled: %@", error);
        }
        else {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - failed to upload handled exception report: %@", [error localizedDescription]);
        }
#endif
        [self handledErroredRequest:task.originalRequest error:error];
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception upload completed successfully");
        if (task.originalRequest) {
            @synchronized(self.payloadByRequest) {
                [self.payloadByRequest removeObjectForKey:task.originalRequest];
            }
        }
        [self.taskStore untrack:task.originalRequest];
        // A successful upload means we're online — drain any reports we persisted while
        // offline and re-send them.
        [self sendOfflineStorage];
    }

    @synchronized(self) {
        if (self.inFlightCount > 0) self.inFlightCount--;
    }
    [self drainPending];
}


- (void) URLSession:(NSURLSession*)session
           dataTask:(NSURLSessionDataTask*)dataTask
 didReceiveResponse:(NSURLResponse*)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload response: %@", response);

    if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
        ((NSHTTPURLResponse*)response).statusCode >= 400) {
        NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - failed to upload handled exception report: %@", response.description);
        // An HTTP status is not a persist-worthy network error (checkErrorToPersist:nil is
        // false), so this path never persists to offline storage.
        [self handledErroredRequest:dataTask.originalRequest error:nil];
    }
    else {
        // Enqueue Data Usage Supportability Metric for /f if request is successful.
        [NRMASupportMetricHelper enqueueDataUseMetric:@"f"
                                                 size:[[[dataTask originalRequest] HTTPBody] length]
                                             received:response.expectedContentLength];
    }

    completionHandler(NSURLSessionResponseAllow);
}

- (void) handledErroredRequest:(NSURLRequest*)request error:(NSError*)error {
    if (request == nil) return;

    // If we're offline, don't burn FDs/sockets cycling failed retries —
    // persist the payload to offline storage (when enabled) so it survives until
    // connectivity returns, then drop the in-memory tracking.
#if !TARGET_OS_WATCH
    NRMAReachability* r = [NewRelicInternalUtils reachability];
    BOOL offline = NO;
    @synchronized(r) {
        offline = ([r currentReachabilityStatus] == NotReachable);
    }
    if (offline) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - offline, persisting report for later");
        [self persistPayloadForRequestToOfflineStorage:request];
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
        return;
    }
#endif

    if ([self.taskStore shouldRetryTask:request]) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - retrying handled exception report upload");
        NSData* body = nil;
        @synchronized(self.payloadByRequest) {
            body = self.payloadByRequest[request];
        }
        if (body == nil || body.length == 0) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - retry has no payload, abandoning report");
            [self.taskStore untrack:request];
            return;
        }
        NSURLSessionUploadTask* uploadTask = [self uploadTaskForRequest:request data:body];
        if (uploadTask == nil) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - retry could not build upload, abandoning report");
            [self.taskStore untrack:request];
            return;
        }
        // The session may produce a fresh originalRequest copy on the new
        // task — rekey the payload store so the next failure path can find
        // the bytes again.
        NSURLRequest* newKey = uploadTask.originalRequest;
        if (newKey && ![newKey isEqual:request]) {
            @synchronized(self.payloadByRequest) {
                self.payloadByRequest[newKey] = body;
            }
        }
        @synchronized(self.retryQueue) {
            [self.retryQueue addObject:uploadTask];
        }
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception report max upload attempts reached. abandoning report.");
        // Retries exhausted: if this was a persist-worthy network error (timeout,
        // connection lost, etc.), keep the report in offline storage to retry later.
        if ([NRMAOfflineStorage checkErrorToPersist:error]) {
            [self persistPayloadForRequestToOfflineStorage:request];
        }
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
    }
}

// Persists the request's payload to offline storage when offline storage is enabled.
- (void) persistPayloadForRequestToOfflineStorage:(NSURLRequest*)request {
    if (![NRMAFlags shouldEnableOfflineStorage]) return;
    NSData* body = nil;
    @synchronized(self.payloadByRequest) {
        body = self.payloadByRequest[request];
    }
    if (body.length == 0) return;
    if ([self.offlineStorage persistDataToDisk:body]) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - persisted handled exception report to offline storage");
    }
}

// Drains offline storage and re-sends each persisted report. Called after a successful
// upload (i.e. when we know we're online). Mirrors NRMAHarvesterConnection.
- (void) sendOfflineStorage {
    if (![NRMAFlags shouldEnableOfflineStorage]) {
        [NRMAOfflineStorage clearAllOfflineDirectories];
        return;
    }
    NSArray<NSData*>* offlineData = [self.offlineStorage getAllOfflineData:YES];
    if (offlineData.count == 0) {
        return;
    }
    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - re-sending %lu offline handled exception report(s)", (unsigned long)offlineData.count);
    for (NSData* data in offlineData) {
        // Re-enter the normal pipeline; a payload that fails again is re-persisted by
        // the failure path above.
        [self sendData:data];
    }
}

@end
