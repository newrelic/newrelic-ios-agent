//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
#import "NRLogger.h"
#import "NRMASupportMetricHelper.h"
#import "NRConstants.h"
#import "NewRelicInternalUtils.h"
#import <NewRelic/NewRelic-Swift.h>

// Hard cap on the in-memory pending queue to guard against unbounded RAM growth
// when the app is offline and callers keep submitting reports.
static const NSUInteger kNRMAHexMaxPending  = 50;

// Limit concurrent uploads so we don't exhaust the per-process FD limit.
static const NSUInteger kNRMAHexMaxInFlight = 4;

// Tighter than NSURLSession defaults to prevent socket exhaustion under low bandwidth.
static const NSTimeInterval kNRMAHexRequestTimeout  = 30.0;
static const NSTimeInterval kNRMAHexResourceTimeout = 60.0;

// Payload container — carries the body, optional persisted-report path, and the
// exactly-once completion that tells the HexStore whether to delete the file.
@interface NRMAHexPayload : NSObject
@property(strong) NSData*  data;
@property(strong) NSString* reportId;   // nil for in-memory (live) uploads
@property(copy)   void(^completion)(BOOL shouldRemove);
- (void) finishWith:(BOOL)shouldRemove;
@end

@implementation NRMAHexPayload
- (void) finishWith:(BOOL)shouldRemove {
    void(^c)(BOOL) = nil;
    @synchronized (self) {
        c = self.completion;
        self.completion = nil; // exactly-once guarantee
    }
    if (c) c(shouldRemove);
}
@end

@interface NRMAHexUploader ()
@property(strong) NSString* host;
@property(strong) NRMARetryingHTTPClient* httpClient;
@property(strong) NSMutableArray<NRMAHexPayload*>* pendingPayloads;
@property(assign) NSUInteger inFlightCount;
@property(assign) BOOL invalidated;
@end

@implementation NRMAHexUploader

- (instancetype) initWithHost:(NSString*)host {
    self = [super init];
    if (self) {
        self.host = host;
        self.pendingPayloads = [NSMutableArray new];
        self.inFlightCount   = 0;
        self.invalidated     = NO;

        NSURLSessionConfiguration* cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.HTTPMaximumConnectionsPerHost = (NSInteger)kNRMAHexMaxInFlight;
        cfg.timeoutIntervalForRequest     = kNRMAHexRequestTimeout;
        cfg.timeoutIntervalForResource    = kNRMAHexResourceTimeout;

        self.httpClient = [[NRMARetryingHTTPClient alloc] initWithSessionConfiguration:cfg
                                                                           retryPolicy:[NRMARetryPolicy new]];
    }
    return self;
}

- (void) sendData:(NSData*)data {
    [self sendData:data reportId:nil completion:nil];
}

- (void) sendData:(NSData*)data reportId:(NSString*)reportId completion:(void(^)(BOOL shouldRemove))completion {
    if (data == nil) {
        if (completion) completion(NO);
        return;
    }

    if (data.length > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"Hex uploader handled exceptions payload is greater than 1 MB, discarding payload");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"f"];
        if (completion) completion(YES);  // oversized — remove from disk
        return;
    }

    NRMAHexPayload* payload = [NRMAHexPayload new];
    payload.data       = data;
    payload.reportId   = reportId;
    payload.completion = completion;

    // Drop oldest when the queue is full to guard against unbounded RAM growth.
    NSMutableArray<NRMAHexPayload*>* dropped = nil;
    @synchronized(self) {
        while (self.pendingPayloads.count >= kNRMAHexMaxPending) {
            if (!dropped) dropped = [NSMutableArray new];
            [dropped addObject:self.pendingPayloads.firstObject];
            [self.pendingPayloads removeObjectAtIndex:0];
            NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - dropping oldest pending payload, queue full");
        }
        [self.pendingPayloads addObject:payload];
    }
    for (NRMAHexPayload* d in dropped) [d finishWith:NO];
    [self drainPending];
}

// retryFailedTasks is kept as a no-op for C++ publisher ABI compatibility.
// Retry is now handled internally by NRMARetryingHTTPClient.
- (void) retryFailedTasks { }

- (void) invalidate {
    @synchronized(self) {
        self.invalidated = YES;
    }
    [self.httpClient invalidate];
}

- (void) dealloc {
    _invalidated = YES;
    [_httpClient invalidate];
}

// MARK: - Private

// Drain as many pending payloads as the in-flight cap allows.
- (void) drainPending {
    NSMutableArray<NRMAHexPayload*>* toSend = nil;
    @synchronized(self) {
        while (self.inFlightCount < kNRMAHexMaxInFlight && self.pendingPayloads.count > 0) {
            if (!toSend) toSend = [NSMutableArray new];
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
    @synchronized(self) {
        if (self.invalidated) {
            if (self.inFlightCount > 0) self.inFlightCount--;
        }
        if (self.invalidated) {
            [payload finishWith:NO];
            return;
        }
    }

    NSMutableURLRequest* request = [self newPostWithURI:self.host];
    if (request == nil) {
        @synchronized(self) { if (self.inFlightCount > 0) self.inFlightCount--; }
        [payload finishWith:NO];
        return;
    }
    request.HTTPMethod = @"POST";
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)payload.data.length]
   forHTTPHeaderField:@"Content-Length"];

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload started");

    NSData* body = payload.data;
    __weak __typeof__(self) weakSelf = self;

    [self.httpClient uploadRequest:[request copy]
                              data:body
                          endpoint:@"f"
                        completion:^(NSData* responseData, NSHTTPURLResponse* response, NSError* error) {
        __strong __typeof__(self) strongSelf = weakSelf;

        BOOL success = (error == nil) && (response.statusCode >= 200 && response.statusCode < 300);
        if (success) {
            NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Handled exception upload completed successfully");
        } else if (error) {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - Upload failed with error: %@", error.localizedDescription);
        } else {
            NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - Upload failed with HTTP %ld", (long)response.statusCode);
        }

        // Enqueue data-use metric on success.
        if (success) {
            [NRMASupportMetricHelper enqueueDataUseMetric:@"f"
                                                     size:(long)body.length
                                                 received:responseData.length];
        }

        // Keep the report on disk only for offline failures (retry next session).
        BOOL isOffline = (error != nil && error.code == NSURLErrorNotConnectedToInternet);
        [payload finishWith:isOffline ? NO : YES];

        if (strongSelf) {
            @synchronized(strongSelf) {
                if (strongSelf.inFlightCount > 0) strongSelf.inFlightCount--;
            }
            [strongSelf drainPending];
        }
    }];
}

@end
