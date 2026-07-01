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

#define kNRMARetryLimit 2 // this will result in 2 additional upload attempts.

// Couples an upload payload with the completion that reports its terminal outcome
// back to the persisted store, plus the per-attempt HTTP-error flag. The completion
// is fired exactly once at the terminal outcome (retries do not fire it). Its BOOL
// means "remove the persisted report?": YES when the upload is confirmed or we have
// permanently given up, NO to keep it for a later retry.
@interface NRMAHexPayload : NSObject
@property(strong) NSData* data;
// Persisted report path; nil for non-persisted (live) uploads. Used as the stable
// de-dupe identifier sent to the collector.
@property(strong) NSString* reportId;
@property(copy) void(^completion)(BOOL shouldRemove);
// Set when a >= 400 HTTP response is seen for the current attempt; reset on retry.
@property(assign) BOOL httpError;
- (void) finishWith:(BOOL)shouldRemove;
@end

@implementation NRMAHexPayload
- (void) finishWith:(BOOL)shouldRemove {
    void(^c)(BOOL) = nil;
    @synchronized (self) {
        c = self.completion;
        self.completion = nil; // guarantee exactly-once
    }
    if (c) {
        c(shouldRemove);
    }
}
@end

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
static const NSTimeInterval kNRMAHexResourceTimeout = 60.0;

@interface NRMAHexUploader()
@property(strong) NSString* host;
@property(strong) NSMutableArray* retryQueue;
@property(strong) NSURLSession* session;
@property(strong) NRMARetryTracker* taskStore;

// Concurrency control — guarded by @synchronized(self).
@property(strong) NSMutableArray<NRMAHexPayload*>* pendingPayloads;
@property(assign) NSUInteger inFlightCount;

// Tracks the upload payload for each in-flight / retryable request, keyed
// by content-equal NSURLRequest. NSURLSessionUploadTask requires the payload
// to come from `fromData:` (not from the request's HTTPBody — iOS warns and
// strips it), so we cannot stash bytes on the request itself. This dictionary
// is the parallel store that lets handledErroredRequest: rebuild the upload
// with the original payload and fire its completion. Guarded by @synchronized(_payloadByRequest).
@property(strong) NSMutableDictionary<NSURLRequest*, NRMAHexPayload*>* payloadByRequest;
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

        NSURLSessionConfiguration* sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = kNRMAHexMaxInFlight;
        sessionConfiguration.timeoutIntervalForRequest = kNRMAHexRequestTimeout;
        sessionConfiguration.timeoutIntervalForResource = kNRMAHexResourceTimeout;
        sessionConfiguration.waitsForConnectivity = NO;

        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
        self.taskStore = [[NRMARetryTracker alloc] initWithRetryLimit:kNRMARetryLimit];
    }
    return self;
}

- (void) sendData:(NSData*)data {
    [self sendData:data reportId:nil completion:nil];
}

- (void) sendData:(NSData*)data reportId:(NSString*)reportId completion:(void(^)(BOOL shouldRemove))completion {
    if (data == nil) {
        // Nothing to upload; keep any persisted report untouched.
        if (completion) completion(NO);
        return;
    }

    if ([data length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"Hex uploader handled exceptions payload is greater than 1 MB, discarding payload");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"f"];
        // Can never be uploaded — remove it so we don't retry it every harvest
        // (matches the crash uploader's handling of oversized reports).
        if (completion) completion(YES);
        return;
    }

    NRMAHexPayload* payload = [NRMAHexPayload new];
    payload.data = data;
    payload.reportId = reportId;
    payload.completion = completion;

    NSMutableArray<NRMAHexPayload*>* dropped = nil;
    @synchronized(self) {
        // Drop oldest first if pending grows beyond the soft cap. This is the
        // memory-spike guard the customer reported — under permanent offline
        // we'd otherwise hold every report in RAM forever.
        while (self.pendingPayloads.count >= kNRMAHexMaxPending) {
            if (dropped == nil) dropped = [NSMutableArray new];
            [dropped addObject:self.pendingPayloads.firstObject];
            [self.pendingPayloads removeObjectAtIndex:0];
            NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - dropping oldest pending payload, queue full");
        }
        [self.pendingPayloads addObject:payload];
    }
    // Report dropped payloads as not-confirmed outside the lock so their reports
    // stay on disk for a later attempt.
    for (NRMAHexPayload* d in dropped) {
        [d finishWith:NO];
    }
    [self drainPending];
}

// Caller must NOT hold @synchronized(self) when invoking. Drains as many
// pending payloads as the in-flight cap allows; reentrant-safe.
- (void) drainPending {
    NSMutableArray<NRMAHexPayload*>* toSend = nil;
    @synchronized(self) {
        while (self.inFlightCount < kNRMAHexMaxInFlight && self.pendingPayloads.count > 0) {
            if (toSend == nil) toSend = [NSMutableArray new];
            [toSend addObject:self.pendingPayloads.firstObject];
            [self.pendingPayloads removeObjectAtIndex:0];
            self.inFlightCount++;
        }
    }
    for (NRMAHexPayload* payload in toSend) {
        [self launchUpload:payload];
    }
}

- (void) launchUpload:(NRMAHexPayload*)payload {
    NSData* data = payload.data;
    NSMutableURLRequest* request = [self newPostWithURI:self.host];
    if (request == nil) {
        @synchronized(self) {
            if (self.inFlightCount > 0) self.inFlightCount--;
        }
        // Couldn't build the request; not confirmed — keep the report for a later attempt.
        [payload finishWith:NO];
        return;
    }

    request.HTTPMethod = @"POST";
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];

    // Important: do NOT set HTTPBody on the request. NSURLSessionUploadTask
    // requires the payload to come exclusively from `fromData:`, and iOS
    // logs a warning + strips the body if both are present. Payload is
    // tracked separately in payloadByRequest so retries can rebuild.

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload started: %@", request);

    NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithRequest:request fromData:data];
    NSURLRequest* key = uploadTask.originalRequest ?: request;

    payload.httpError = NO;
    @synchronized(self.payloadByRequest) {
        self.payloadByRequest[key] = payload;
    }
    [self.taskStore track:key];
    [uploadTask resume];
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
    // Defense-in-depth: NSURLSession holds a strong ref to its delegate
    // (self), so without an explicit invalidate the session + delegate +
    // any in-flight tasks live forever. The publisher dtor normally
    // invalidates first, but covering the dealloc path guarantees
    // FDs and sockets are released even if ownership shifts.
    [_session invalidateAndCancel];
}

- (void)  URLSession:(NSURLSession*)session
                task:(NSURLSessionTask*)task
didCompleteWithError:(nullable NSError*)error {

    NSURLRequest* key = task.originalRequest;
    NRMAHexPayload* payload = nil;
    @synchronized(self.payloadByRequest) {
        payload = key ? self.payloadByRequest[key] : nil;
    }
    // A >= 400 response (recorded in didReceiveResponse) completes without a
    // transport error, so fold that into the failure decision here — this is
    // the single terminal handler for the attempt.
    BOOL httpError = payload.httpError;

    if (error || httpError) {
#if !TARGET_OS_WATCH
        if (error.code == kCFURLErrorCancelled) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - Handled exception upload cancelled: %@", error);
        }
        else if (error) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - failed to upload handled exception report: %@", [error localizedDescription]);
        }
#endif
        [self handledErroredRequest:key];
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception upload completed successfully");
        if (key) {
            @synchronized(self.payloadByRequest) {
                [self.payloadByRequest removeObjectForKey:key];
            }
        }
        [self.taskStore untrack:key];
        // Upload confirmed — let the store delete the persisted report (shouldRemove = YES).
        [payload finishWith:YES];
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
        // Record the HTTP failure; the terminal retry/abandon decision (and the
        // payload completion) is made in didCompleteWithError so it happens
        // exactly once per attempt.
        NSURLRequest* key = dataTask.originalRequest;
        @synchronized(self.payloadByRequest) {
            NRMAHexPayload* payload = key ? self.payloadByRequest[key] : nil;
            payload.httpError = YES;
        }
    }
    else {
        // Enqueue Data Usage Supportability Metric for /f if request is successful.
        [NRMASupportMetricHelper enqueueDataUseMetric:@"f"
                                                 size:[[[dataTask originalRequest] HTTPBody] length]
                                             received:response.expectedContentLength];
    }

    completionHandler(NSURLSessionResponseAllow);
}

- (void) handledErroredRequest:(NSURLRequest*)request {
    if (request == nil) return;

    NRMAHexPayload* payload = nil;
    @synchronized(self.payloadByRequest) {
        payload = self.payloadByRequest[request];
    }

    // If we're offline, don't burn FDs/sockets cycling failed retries —
    // keep the report on disk and let the next harvest retry when reachable.
#if !TARGET_OS_WATCH
    NRMAReachability* r = [NewRelicInternalUtils reachability];
    BOOL offline = NO;
    @synchronized(r) {
        offline = ([r currentReachabilityStatus] == NotReachable);
    }
    if (offline) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - offline, deferring retry");
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
        [payload finishWith:NO];
        return;
    }
#endif

    if ([self.taskStore shouldRetryTask:request]) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - retrying handled exception report upload");
        NSData* body = payload.data;
        if (body == nil || body.length == 0) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - retry has no payload, abandoning report");
            @synchronized(self.payloadByRequest) {
                [self.payloadByRequest removeObjectForKey:request];
            }
            [self.taskStore untrack:request];
            [payload finishWith:NO];
            return;
        }
        NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithRequest:request fromData:body];
        // The session may produce a fresh originalRequest copy on the new task.
        // Requests with identical content are -isEqual:, so the retried task's
        // originalRequest maps to the same payloadByRequest / retry-tracker slot;
        // re-keying just ensures the payload is found again. Reset the per-attempt
        // HTTP-error flag so the retry starts clean.
        payload.httpError = NO;
        NSURLRequest* newKey = uploadTask.originalRequest;
        if (newKey) {
            @synchronized(self.payloadByRequest) {
                self.payloadByRequest[newKey] = payload;
            }
        }
        @synchronized(self.retryQueue) {
            [self.retryQueue addObject:uploadTask];
        }
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception report max upload attempts reached. abandoning report.");
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
        // Retries exhausted — not confirmed; remove the report on disk
        [payload finishWith:YES];
    }
}

@end
