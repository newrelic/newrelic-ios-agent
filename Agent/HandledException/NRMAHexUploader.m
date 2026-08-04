//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
#import "NRMARetryOrchestrator.h"
#import "NRLogger.h"
#import "NRMASupportMetricHelper.h"
#import "NRConstants.h"
#import "NewRelicInternalUtils.h"
#import "NRMAReachability.h"

#define kNRMAHexRetryLimit 5

static const NSTimeInterval kNRMAHexRequestTimeout = 30.0;
static const NSTimeInterval kNRMAHexResourceTimeout = 60.0;

@interface NRMAHexUploader()
@property(strong) NSString* host;
@property(strong) NSURLSession* session;
@property(strong) NRMARetryOrchestrator* orchestrator;
@end

@implementation NRMAHexUploader

- (instancetype) initWithHost:(NSString*)host {
    self = [super init];
    if (self) {
        self.host = host;

        NSURLSessionConfiguration* sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.timeoutIntervalForRequest = kNRMAHexRequestTimeout;
        sessionConfiguration.timeoutIntervalForResource = kNRMAHexResourceTimeout;

        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        self.orchestrator = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];
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

    if ([data length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"Hex uploader handled exceptions payload is greater than 1 MB, discarding payload");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"f"];
        if (completion) completion(YES);
        return;
    }

    NSMutableURLRequest* request = [self newPostWithURI:self.host];
    if (request == nil) {
        if (completion) completion(NO);
        return;
    }

    request.HTTPMethod = @"POST";
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];

    NRLOG_AGENT_VERBOSE(@"NEWRELIC HEX UPLOADER - Hex Upload started: %@", request);

    NSURLSession *session = self.session;
    unsigned long dataLength = (unsigned long)data.length;

    NRMAExecuteRequestBlock executeRequest = ^(void (^onResponse)(NSHTTPURLResponse*, NSData*, NSError*)) {
        [[session uploadTaskWithRequest:request
                               fromData:data
                      completionHandler:^(NSData *responseBody, NSURLResponse *response, NSError *error) {
            NRLOG_AGENT_DEBUG(@"NEWRELIC HEX UPLOADER - Hex Upload response: %@", response);
            if (error) {
                NRLOG_AGENT_ERROR(@"NEWRELIC HEX UPLOADER - failed to upload handled exception report: %@",
                                  [error localizedDescription]);
            }
            onResponse((NSHTTPURLResponse *)response, responseBody, error);
        }] resume];
    };

    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = ^BOOL(NSHTTPURLResponse *response, NSError *error) {
        if (error != nil) return YES;
        return response.statusCode >= 400;
    };

    [self.orchestrator executeWithMaxRetries:kNRMAHexRetryLimit
                              executeRequest:executeRequest
                                 shouldRetry:shouldRetry
                                waitForDelay:[NRMARetryOrchestrator asyncWaitForDelayOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)]
                                  completion:^(NSHTTPURLResponse *response, NSData *responseBody, NSError *error, NSInteger retryCount) {
        BOOL success = (error == nil && response.statusCode < 400);
        if (success) {
            NRLOG_AGENT_DEBUG(@"NEWRELIC HEX UPLOADER - Handled exception upload completed successfully");
            [NRMASupportMetricHelper enqueueDataUseMetric:@"f"
                                                     size:dataLength
                                                 received:response.expectedContentLength];
        } else {
            NRLOG_AGENT_DEBUG(@"NEWRELIC HEX UPLOADER - Handled exception report max upload attempts reached. abandoning report.");
        }
        if (completion) completion(success);
    }];
}

- (void) retryFailedTasks {
    // Retries are handled immediately by NRMARetryOrchestrator inside sendData:.
}

- (void) invalidate {
    [self.session finishTasksAndInvalidate];
}

- (void) dealloc {
    [_session finishTasksAndInvalidate];
}

@end
