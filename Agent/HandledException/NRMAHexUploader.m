//
//  NRMAHexUploader.m
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright (c) 2017 New Relic. All rights reserved.
//

#import "NRMAHexUploader.h"
#import "NRMARetryTracker.h"
#import "NRLogger.h"
#include <libkern/OSAtomic.h>
#import "NRMASupportMetricHelper.h"

#define kNRMARetryLimit 2 // this will result in 2 additional upload attempts.
#define kNRMAMaxPayloadSizeLimit 1000000

@interface NRMAHexUploader()
@property(strong) NSString* host;
@property(strong) NSMutableArray* retryQueue;
@property(strong) NSURLSession* session;
@property(strong) NRMARetryTracker* taskStore;
@end

@implementation NRMAHexUploader

- (instancetype) initWithHost:(NSString*)host {
    self = [super init];
    if (self) {
        self.host = host;
        self.retryQueue = [NSMutableArray new];
        NSURLSessionConfiguration* sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
        self.taskStore = [[NRMARetryTracker alloc] initWithRetryLimit:kNRMARetryLimit];
    }
    return self;
}

- (void) sendData:(NSData*)data {

    if (data == nil) return;

    NSMutableURLRequest* request = [self newPostWithURI:self.host];

    if (request == nil) return;

    request.HTTPMethod = @"POST";
    request.HTTPBody = data;

    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu",(unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    
    if([[request HTTPBody] length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_ERROR(@"Hex uploader handled exceptions payload is greater than 1 MB, discarding payload");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"f"];
        return;
    }
    
    
    NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithStreamedRequest:request];
    [self.taskStore track:uploadTask.originalRequest];
    [uploadTask resume];
}

- (void) retryFailedTasks {
    NSArray* localRetryQueue;
    @synchronized(self.retryQueue) {
        localRetryQueue = self.retryQueue;
        // The following line prevents this temp local variable from being optimized out.
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
    
}

- (void)  URLSession:(NSURLSession*)session
                task:(NSURLSessionTask*)task
didCompleteWithError:(nullable NSError*)error {
    // We cancel http errors in other delegate method.
    if (error && error.code != kCFURLErrorCancelled) {
        NRLOG_ERROR(@"failed to upload handled exception report: %@", [error localizedDescription]);
        [self handledErroredRequest:task.originalRequest];
    }
}


- (void) URLSession:(NSURLSession*)session
           dataTask:(NSURLSessionDataTask*)dataTask
 didReceiveResponse:(NSURLResponse*)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

    NSInteger statusCode = httpResponse.statusCode;

    if (statusCode >= 400) {
        NRLOG_ERROR(@"failed to upload handled exception report: %@", httpResponse.description);
        [self handledErroredRequest:dataTask.originalRequest];
    }
    else {
        // Enqueue Data Usage Supportability Metric for /f if request is successful.
        [NRMASupportMetricHelper enqueueDataUseMetric:@"f"
                                                 size:[[[dataTask originalRequest] HTTPBody] length]
                                             received:response.expectedContentLength];
    }
    completionHandler(NSURLSessionResponseCancel);
}

- (void) handledErroredRequest:(NSURLRequest*)request {
    if ([self.taskStore shouldRetryTask:request]) {
        NRLOG_VERBOSE(@"retrying handled exception report upload");
        NSURLSessionUploadTask* uploadTask = [self.session uploadTaskWithStreamedRequest:request];
        @synchronized(self.retryQueue) {
            [self.retryQueue addObject:uploadTask];
        }
    } else {
        NRLOG_VERBOSE(@"Handled exception report max upload attempts reached. abandoning report.");
        [self.taskStore untrack:request];
    }
}

@end
