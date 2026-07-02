//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
#import "NRMARetryTracker.h"
#import "NRMAPersistentRetryTracker.h"
#import "NRLogger.h"
#include <libkern/OSAtomic.h>
#import "NRMASupportMetricHelper.h"
#import "NRConstants.h"
#import "NewRelicInternalUtils.h"
#import "NRMAReachability.h"

#define kNRMARetryLimit 2 // this will result in 2 additional upload attempts.

// Cross-launch retry budget for a PERSISTED report, keyed by its (unique, timestamped)
// filename and tracked on disk by NRMAPersistentRetryTracker. Unlike kNRMARetryLimit
// (per-request, in memory, resets each launch), this bounds the TOTAL number of failed
// server attempts a single persisted report may accrue across app restarts before it is
// dropped — so a permanently-un-uploadable report is not retried forever every launch.
#define kNRMAHexPersistedRetryLimit 5

// Couples an upload payload with the completion that reports its terminal outcome
// back to the persisted store, plus the per-attempt HTTP-error flag. The completion
// is fired exactly once at the terminal outcome (retries do not fire it). Its BOOL
// means "remove the persisted report?": YES when the upload is confirmed or we have
// permanently given up, NO to keep it for a later retry.
@interface NRMAHexPayload : NSObject
@property(strong) NSData* data;
// Persisted report path (its on-disk file path); nil for non-persisted (live) uploads.
// Used as the key for the cross-launch retry budget (NRMAPersistentRetryTracker).
// NOTE: not yet sent to the collector as a de-dupe/idempotency identifier — that wire
// contract is still to be confirmed with the collector.
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
        NRLOG_AGENT_VERBOSE(@"[HexDelete] payload finishWith:%@ for report %@ — invoking store completion",
                            shouldRemove ? @"REMOVE" : @"KEEP", self.reportId ?: @"(live/no-reportId)");
        c(shouldRemove);
    } else {
        // No completion means either a live (non-persisted) upload OR this payload's
        // terminal outcome was already reported. If it had a reportId, the second
        // path means the persisted store never hears about this resolution.
        NRLOG_AGENT_VERBOSE(@"[HexDelete] payload finishWith:%@ for report %@ — no completion to fire "
                            @"(live upload or already resolved)",
                            shouldRemove ? @"REMOVE" : @"KEEP", self.reportId ?: @"(live/no-reportId)");
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
// Cross-launch retry budget for persisted reports, keyed by report filename.
@property(strong) NRMAPersistentRetryTracker* persistentRetryTracker;

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
        self.persistentRetryTracker = [[NRMAPersistentRetryTracker alloc] initWithRetryLimit:kNRMAHexPersistedRetryLimit];
    }
    return self;
}

- (void) sendData:(NSData*)data {
    [self sendData:data reportId:nil completion:nil];
}

- (void) sendData:(NSData*)data reportId:(NSString*)reportId completion:(void(^)(BOOL shouldRemove))completion {
    if (data == nil) {
        // Nothing to upload; keep any persisted report untouched.
        NRLOG_AGENT_VERBOSE(@"[HexDelete] sendData: nil data for report %@ — completion(KEEP)",
                            reportId ?: @"(live)");
        if (completion) completion(NO);
        return;
    }

    if ([data length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"[HexDelete] sendData: payload for report %@ is greater than 1 MB (%lu bytes), "
                          @"discarding and completion(REMOVE)", reportId ?: @"(live)", (unsigned long)data.length);
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
            NRMAHexPayload* victim = self.pendingPayloads.firstObject;
            [dropped addObject:victim];
            [self.pendingPayloads removeObjectAtIndex:0];
            NRLOG_AGENT_WARNING(@"[HexDelete] sendData: pending queue full (%lu), dropping oldest pending "
                                @"report %@ (will be KEPT on disk for a later attempt)",
                                (unsigned long)kNRMAHexMaxPending, victim.reportId ?: @"(live)");
        }
        [self.pendingPayloads addObject:payload];
        NRLOG_AGENT_VERBOSE(@"[HexDelete] sendData: queued report %@ (pending=%lu, inFlight=%lu)",
                            reportId ?: @"(live)", (unsigned long)self.pendingPayloads.count,
                            (unsigned long)self.inFlightCount);
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
        NRLOG_AGENT_ERROR(@"[HexDelete] launchUpload: failed to build request for report %@ — completion(KEEP)",
                          payload.reportId ?: @"(live)");
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

    NRLOG_AGENT_VERBOSE(@"[HexDelete] launchUpload: starting upload for report %@: %@",
                        payload.reportId ?: @"(live)", request);

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

    // HOLE WATCH: if we cannot find the payload for this completed task, we can
    // neither confirm nor defer the persisted report — its completion never
    // fires, so the C++ in-flight claim is never released and the file is stuck
    // in-flight for the rest of this process (recovered only on relaunch). This
    // also means a >= 400 for an untracked task is silently treated as success.
    if (payload == nil) {
        NRLOG_AGENT_WARNING(@"[HexDelete] didCompleteWithError: NO payload found for completed task "
                            @"(key=%@, error=%@). Persisted report (if any) cannot be resolved this "
                            @"session and stays in-flight until relaunch.", key, error);
    } else {
        NRLOG_AGENT_VERBOSE(@"[HexDelete] didCompleteWithError: report %@ error=%@ httpError=%@ inFlight=%lu",
                            payload.reportId ?: @"(live)", error ? error.localizedDescription : @"nil",
                            httpError ? @"YES" : @"NO", (unsigned long)self.inFlightCount);
    }

    // A logical upload occupies exactly one in-flight slot from launchUpload until
    // it TERMINALLY resolves. A retry is a continuation of the same logical upload,
    // so when handledErroredRequest queues a retry we must NOT release the slot here
    // — otherwise the retry (resumed later by retryFailedTasks) runs uncounted and
    // this handler double-decrements, driving inFlightCount to 0 and defeating the
    // kNRMAHexMaxInFlight FD/socket cap (hole #5).
    BOOL slotReleased = NO;
    if (error || httpError) {
#if !TARGET_OS_WATCH
        if (error.code == kCFURLErrorCancelled) {
            NRLOG_AGENT_ERROR(@"[HexDelete] Handled exception upload cancelled (report %@): %@",
                              payload.reportId ?: @"(live)", error);
        }
        else if (error) {
            NRLOG_AGENT_ERROR(@"[HexDelete] failed to upload handled exception report %@: %@",
                              payload.reportId ?: @"(live)", [error localizedDescription]);
        }
        else {
            NRLOG_AGENT_ERROR(@"[HexDelete] handled exception report %@ received an HTTP >= 400 response",
                              payload.reportId ?: @"(live)");
        }
#endif
        BOOL willRetry = [self handledErroredRequest:key];
        if (!willRetry) {
            // Terminal failure (offline defer, abandon, or retries exhausted) —
            // release the slot now.
            @synchronized(self) {
                if (self.inFlightCount > 0) self.inFlightCount--;
            }
            slotReleased = YES;
        }
        // willRetry == YES: keep the slot; the retried task's completion releases it.
    } else {
        NRLOG_AGENT_VERBOSE(@"[HexDelete] Handled exception upload completed successfully for report %@",
                            payload.reportId ?: @"(live)");
        if (key) {
            @synchronized(self.payloadByRequest) {
                [self.payloadByRequest removeObjectForKey:key];
            }
        }
        [self.taskStore untrack:key];
        // Confirmed upload: clear the cross-launch retry counter and let the store
        // delete the persisted report (shouldRemove = YES).
        [self.persistentRetryTracker clearReportId:payload.reportId];
        [payload finishWith:YES];
        @synchronized(self) {
            if (self.inFlightCount > 0) self.inFlightCount--;
        }
        slotReleased = YES;
    }

    if (slotReleased) {
        // A freed slot may let a queued report launch.
        [self drainPending];
    }
}


- (void) URLSession:(NSURLSession*)session
           dataTask:(NSURLSessionDataTask*)dataTask
 didReceiveResponse:(NSURLResponse*)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload response: %@", response);

    if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
        ((NSHTTPURLResponse*)response).statusCode >= 400) {
        NRLOG_AGENT_ERROR(@"[HexDelete] didReceiveResponse: HTTP %ld for handled exception report: %@",
                          (long)((NSHTTPURLResponse*)response).statusCode, response.description);
        // Record the HTTP failure; the terminal retry/abandon decision (and the
        // payload completion) is made in didCompleteWithError so it happens
        // exactly once per attempt.
        NSURLRequest* key = dataTask.originalRequest;
        @synchronized(self.payloadByRequest) {
            NRMAHexPayload* payload = key ? self.payloadByRequest[key] : nil;
            if (payload == nil) {
                // HOLE WATCH: the >= 400 cannot be recorded against a payload, so
                // didCompleteWithError will see httpError=NO and treat this failed
                // upload as a success (no retry). If the task also has no payload
                // there, the persisted report is neither retried nor deleted.
                NRLOG_AGENT_WARNING(@"[HexDelete] didReceiveResponse: HTTP >= 400 but NO payload tracked "
                                    @"for key=%@ — failure will not be recorded, upload may be mistaken "
                                    @"for success", key);
            } else {
                NRLOG_AGENT_VERBOSE(@"[HexDelete] didReceiveResponse: recorded httpError on report %@",
                                    payload.reportId ?: @"(live)");
            }
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

// Resolves a failed upload attempt: either queues a retry (returns YES, meaning the
// logical upload keeps its in-flight slot) or terminally resolves it — offline defer,
// abandon, or retries exhausted — (returns NO, meaning the caller should release the
// slot). For persisted reports (payload.reportId != nil) the retry budget is the
// cross-launch NRMAPersistentRetryTracker, so the limit survives app restarts and a
// permanently-un-uploadable report is eventually dropped instead of retried forever.
- (BOOL) handledErroredRequest:(NSURLRequest*)request {
    if (request == nil) {
        NRLOG_AGENT_WARNING(@"[HexDelete] handledErroredRequest: nil request — cannot resolve any "
                            @"persisted report for this failure");
        return NO;
    }

    NRMAHexPayload* payload = nil;
    @synchronized(self.payloadByRequest) {
        payload = self.payloadByRequest[request];
    }
    if (payload == nil) {
        // HOLE WATCH: no payload for this errored request means no completion can
        // be fired — the persisted report's in-flight claim is never released.
        NRLOG_AGENT_WARNING(@"[HexDelete] handledErroredRequest: NO payload for errored request %@ — "
                            @"persisted report cannot be retried or removed this session", request);
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
        // Offline is not a server attempt, so it does NOT consume the retry budget.
        NRLOG_AGENT_VERBOSE(@"[HexDelete] handledErroredRequest: offline, deferring retry for report %@ "
                            @"(KEEP on disk, retry budget untouched)", payload.reportId ?: @"(live)");
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
        [payload finishWith:NO];
        return NO;
    }
#endif

    // Persisted reports use the cross-launch budget; live (reportId == nil) uploads
    // keep the in-memory per-request counter.
    BOOL shouldRetry;
    if (payload.reportId.length) {
        shouldRetry = ![self.persistentRetryTracker recordAttemptAndShouldDrop:payload.reportId];
    } else {
        shouldRetry = [self.taskStore shouldRetryTask:request];
    }

    if (shouldRetry) {
        NRLOG_AGENT_VERBOSE(@"[HexDelete] handledErroredRequest: retrying upload for report %@",
                            payload.reportId ?: @"(live)");
        NSData* body = payload.data;
        if (body == nil || body.length == 0) {
            NRLOG_AGENT_ERROR(@"[HexDelete] handledErroredRequest: retry has no payload for report %@, "
                              @"abandoning attempt (KEEP on disk)", payload.reportId ?: @"(live)");
            @synchronized(self.payloadByRequest) {
                [self.payloadByRequest removeObjectForKey:request];
            }
            [self.taskStore untrack:request];
            [payload finishWith:NO];
            return NO;
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
        NRLOG_AGENT_VERBOSE(@"[HexDelete] handledErroredRequest: report %@ queued for retry on next "
                            @"retryFailedTasks (retryQueue size=%lu)", payload.reportId ?: @"(live)",
                            (unsigned long)self.retryQueue.count);
        return YES;
    } else {
        NRLOG_AGENT_WARNING(@"[HexDelete] handledErroredRequest: retry budget exhausted for report %@ "
                            @"— abandoning and completion(REMOVE) (report deleted despite never confirming "
                            @"upload)", payload.reportId ?: @"(live)");
        @synchronized(self.payloadByRequest) {
            [self.payloadByRequest removeObjectForKey:request];
        }
        [self.taskStore untrack:request];
        // Retry budget exhausted — clear the cross-launch counter so a future report
        // reusing the (timestamped, so effectively unique) name starts clean.
        [self.persistentRetryTracker clearReportId:payload.reportId];
        // Not confirmed; give up and remove the report on disk.
        [payload finishWith:YES];
        return NO;
    }
}

@end
