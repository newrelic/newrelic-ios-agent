//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
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
// Persisted report path; nil for non-persisted (live) uploads.
@property(strong) NSString* reportId;
@property(copy) void(^completion)(BOOL shouldRemove);
// Set when a >= 400 HTTP response is seen for the current attempt; reset on retry.
@property(assign) BOOL httpError;
// Number of retries already performed for this payload. The retry count lives here,
// on the payload, rather than in an external request-keyed tracker: every hex upload
// targets the same URL with no HTTPBody (the bytes go via -fromData:), so their
// NSURLRequests are all -isEqual: and a request-keyed counter is shared across
// unrelated reports. The payload survives across a retry (it is re-registered under
// the new task's identifier), so it is the natural owner of the counter.
@property(assign) NSUInteger attempts;
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

// Concurrency control — guarded by @synchronized(self).
@property(strong) NSMutableArray<NRMAHexPayload*>* pendingPayloads;
@property(assign) NSUInteger inFlightCount;

// Maps an in-flight / retryable task to its payload, keyed by the task's
// -taskIdentifier (unique within an NSURLSession). It CANNOT be keyed by the
// NSURLRequest: NSURLSessionUploadTask requires the payload to come from
// `fromData:` (setting HTTPBody makes iOS warn and strip it), so every hex
// request has the same URL/method/headers and no body — they are all -isEqual:
// and would collide on a single dictionary slot. When that happened, concurrent
// uploads overwrote each other's payload and completions resolved to the wrong
// (or a removed) payload, so a confirmed report's file was never deleted and got
// re-uploaded on the next launch (duplicate reports). Keying by taskIdentifier
// gives each upload its own slot. Guarded by @synchronized(_payloadByTaskId).
@property(strong) NSMutableDictionary<NSNumber*, NRMAHexPayload*>* payloadByTaskId;
@end

@implementation NRMAHexUploader

- (instancetype) initWithHost:(NSString*)host {
    self = [super init];
    if (self) {
        self.host = host;
        self.retryQueue = [NSMutableArray new];
        self.pendingPayloads = [NSMutableArray new];
        self.payloadByTaskId = [NSMutableDictionary new];
        self.inFlightCount = 0;

        NSURLSessionConfiguration* sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = kNRMAHexMaxInFlight;
        sessionConfiguration.timeoutIntervalForRequest = kNRMAHexRequestTimeout;
        sessionConfiguration.timeoutIntervalForResource = kNRMAHexResourceTimeout;
        sessionConfiguration.waitsForConnectivity = NO;

        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
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
    // logs a warning + strips the body if both are present. The payload is
    // tracked separately in payloadByTaskId (keyed by task identifier) so
    // retries can rebuild and completions can find the right payload.

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload started: %@", request);

    NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithRequest:request fromData:data];

    payload.httpError = NO;
    @synchronized(self.payloadByTaskId) {
        self.payloadByTaskId[@(uploadTask.taskIdentifier)] = payload;
    }
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

    NSNumber* key = @(task.taskIdentifier);
    NRMAHexPayload* payload = nil;
    @synchronized(self.payloadByTaskId) {
        payload = self.payloadByTaskId[key];
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
        [self handledErroredTask:task payload:payload];
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception upload completed successfully");
        @synchronized(self.payloadByTaskId) {
            [self.payloadByTaskId removeObjectForKey:key];
        }
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
        @synchronized(self.payloadByTaskId) {
            NRMAHexPayload* payload = self.payloadByTaskId[@(dataTask.taskIdentifier)];
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

- (void) handledErroredTask:(NSURLSessionTask*)task payload:(NRMAHexPayload*)payload {
    if (task == nil) return;

    NSNumber* oldKey = @(task.taskIdentifier);

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
        @synchronized(self.payloadByTaskId) {
            [self.payloadByTaskId removeObjectForKey:oldKey];
        }
        [payload finishWith:NO];
        return;
    }
#endif

    if (payload.attempts < kNRMARetryLimit) {
        payload.attempts += 1;
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - retrying handled exception report upload");
        NSData* body = payload.data;
        if (body == nil || body.length == 0) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - retry has no payload, abandoning report");
            @synchronized(self.payloadByTaskId) {
                [self.payloadByTaskId removeObjectForKey:oldKey];
            }
            [payload finishWith:NO];
            return;
        }
        // Rebuild the upload from the original request. The new task gets its own
        // -taskIdentifier, so move the payload from the old key to the new one and
        // reset the per-attempt HTTP-error flag so the retry starts clean.
        NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithRequest:task.originalRequest fromData:body];
        payload.httpError = NO;
        @synchronized(self.payloadByTaskId) {
            [self.payloadByTaskId removeObjectForKey:oldKey];
            self.payloadByTaskId[@(uploadTask.taskIdentifier)] = payload;
        }
        @synchronized(self.retryQueue) {
            [self.retryQueue addObject:uploadTask];
        }
    } else {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception report max upload attempts reached. abandoning report.");
        @synchronized(self.payloadByTaskId) {
            [self.payloadByTaskId removeObjectForKey:oldKey];
        }
        // Retries exhausted — not confirmed; remove the report on disk
        [payload finishWith:YES];
    }
}

@end
