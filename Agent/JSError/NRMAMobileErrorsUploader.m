//
//  NRMAMobileErrorsUploader.m
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAMobileErrorsUploader.h"
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"

static const NSInteger kRetryLimit = 2;
static const NSInteger kMaxPayloadSizeLimitBytes = 1048576; // 1 MB

@interface NRMAMobileErrorsUploader ()

@property (nonatomic, strong) NSURL* baseURL;
@property (nonatomic, strong) NSString* applicationToken;
@property (nonatomic, strong) NSString* appVersion;
@property (nonatomic, assign) BOOL useSSL;
@property (nonatomic, strong) NSURLSession* session;
@property (nonatomic, strong) NSMutableArray<NSURLRequest*>* retryQueue;
@property (nonatomic, strong) NSLock* retryQueueLock;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*>* retryTracker;
@property (nonatomic, strong) NSLock* retryTrackerLock;

@end

@implementation NRMAMobileErrorsUploader

- (void) dealloc {
    [self.session finishTasksAndInvalidate];
}

- (instancetype) initWithHost:(NSString*)host
             applicationToken:(NSString*)applicationToken
                   appVersion:(NSString*)appVersion
                       useSSL:(BOOL)useSSL {

    if (host == nil || host.length == 0) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: host is required");
        return nil;
    }

    if (applicationToken == nil || applicationToken.length == 0) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: applicationToken is required");
        return nil;
    }

    if (appVersion == nil || appVersion.length == 0) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: appVersion is required");
        return nil;
    }

    self = [super init];
    if (self) {
        // Construct base URL
        NSString* scheme = useSSL ? @"https" : @"http";
        NSString* urlString = [NSString stringWithFormat:@"%@://%@/mobile/errors", scheme, host];
        self.baseURL = [NSURL URLWithString:urlString];

        if (!self.baseURL) {
            NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: invalid URL");
            return nil;
        }

        self.applicationToken = applicationToken;
        self.appVersion = appVersion;
        self.useSSL = useSSL;

        // Initialize collections
        self.retryQueue = [NSMutableArray array];
        self.retryQueueLock = [[NSLock alloc] init];
        self.retryTracker = [NSMutableDictionary dictionary];
        self.retryTrackerLock = [[NSLock alloc] init];

        // Configure URL session
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 60.0;
        config.timeoutIntervalForResource = 120.0;
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

        NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader initialized with URL: %@", self.baseURL);
    }

    return self;
}

#pragma mark - Public Methods

- (void) sendPayload:(NSDictionary*)payload
           sessionId:(NSString* _Nullable)sessionId
          entityGuid:(NSString* _Nullable)entityGuid
           accountId:(NSNumber* _Nullable)accountId
    trustedAccountId:(NSNumber* _Nullable)trustedAccountId
        sessionToken:(NSString* _Nullable)sessionToken
    agentConfigToken:(NSString* _Nullable)agentConfigToken {
    // Serialize to JSON
    NSError* jsonError = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];

    if (jsonError || !jsonData) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Failed to serialize payload to JSON: %@", jsonError);
        return;
    }

    // Check payload size
    if (jsonData.length > kMaxPayloadSizeLimitBytes) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Payload exceeds 1 MB limit (%lu bytes), discarding", (unsigned long)jsonData.length);
        return;
    }

    // Create URL with query parameters
    NSURLComponents* urlComponents = [NSURLComponents componentsWithURL:self.baseURL resolvingAgainstBaseURL:NO];
    if (!urlComponents) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Failed to create URL components");
        return;
    }

    // Add required query parameters
    urlComponents.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"protocol_version" value:@"1"],
        [NSURLQueryItem queryItemWithName:@"platform" value:@"reactnative"]
    ];

    NSURL* url = urlComponents.URL;
    if (!url) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Failed to construct URL with query params");
        return;
    }

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;

    // Add headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)jsonData.length] forHTTPHeaderField:@"Content-Length"];
    [request setValue:self.applicationToken forHTTPHeaderField:@"X-App-License-Key"];

    // Add New Relic headers
    [self addNewRelicHeadersToRequest:request
                            sessionId:sessionId
                           entityGuid:entityGuid
                            accountId:accountId
                     trustedAccountId:trustedAccountId
                         sessionToken:sessionToken
                     agentConfigToken:agentConfigToken];

    NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Sending payload to %@", url);
    NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Payload size: %lu bytes", (unsigned long)jsonData.length);

    // Log all headers for debugging
    NSLog(@"========== Mobile Errors Request Headers ==========");
    NSLog(@"URL: %@", url);
    NSLog(@"Payload size: %lu bytes", (unsigned long)jsonData.length);
    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL* stop) {
        NSLog(@"  %@: %@", key, value);
    }];
    NSLog(@"===================================================");

    // Track for retry
    [self trackRequest:request];

    // Create and start upload task
    NSURLSessionDataTask* task = [self.session dataTaskWithRequest:request];
    [task resume];
}

- (void) retryFailedUploads {
    [self.retryQueueLock lock];
    NSArray<NSURLRequest*>* requestsToRetry = [NSArray arrayWithArray:self.retryQueue];
    [self.retryQueue removeAllObjects];
    [self.retryQueueLock unlock];

    if (requestsToRetry.count == 0) {
        return;
    }

    NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Retrying %lu failed uploads", (unsigned long)requestsToRetry.count);

    for (NSURLRequest* request in requestsToRetry) {
        NSURLSessionDataTask* task = [self.session dataTaskWithRequest:request];
        [task resume];
    }
}

- (void) invalidate {
    [self.session finishTasksAndInvalidate];
}

#pragma mark - Private Methods

- (void) addNewRelicHeadersToRequest:(NSMutableURLRequest*)request
                           sessionId:(NSString* _Nullable)sessionId
                          entityGuid:(NSString* _Nullable)entityGuid
                           accountId:(NSNumber* _Nullable)accountId
                    trustedAccountId:(NSNumber* _Nullable)trustedAccountId
                        sessionToken:(NSString* _Nullable)sessionToken
                    agentConfigToken:(NSString* _Nullable)agentConfigToken {
    // Standard New Relic Mobile headers (from Mobile Errors Protocol)
    [request setValue:[NewRelicInternalUtils agentVersion] forHTTPHeaderField:@"X-NewRelic-Agent-Version"];
    [request setValue:self.appVersion forHTTPHeaderField:@"X-NewRelic-App-Version"];
    [request setValue:[NewRelicInternalUtils osName] forHTTPHeaderField:@"X-NewRelic-Os-Name"];

    // Session token (from connect response request_headers_map)
    if (sessionToken && sessionToken.length > 0) {
        [request setValue:sessionToken forHTTPHeaderField:@"X-NewRelic-Session"];
    } else if (sessionId && sessionId.length > 0) {
        // Fallback to session ID if token not available
        [request setValue:sessionId forHTTPHeaderField:@"X-NewRelic-Session"];
    }

    // Agent configuration token (from connect response request_headers_map)
    if (agentConfigToken && agentConfigToken.length > 0) {
        [request setValue:agentConfigToken forHTTPHeaderField:@"X-NewRelic-AgentConfiguration"];
    }

    // Entity GUID
    if (entityGuid && entityGuid.length > 0) {
        [request setValue:entityGuid forHTTPHeaderField:@"X-NewRelic-Entity-Guid"];
    }

    // Account IDs (required by protocol)
    if (accountId) {
        [request setValue:[accountId stringValue] forHTTPHeaderField:@"X-NewRelic-Account-Id"];
    }
    if (trustedAccountId) {
        [request setValue:[trustedAccountId stringValue] forHTTPHeaderField:@"X-NewRelic-Trusted-Account-Id"];
    }
}

- (void) trackRequest:(NSURLRequest*)request {
    NSString* url = request.URL.absoluteString;
    if (!url) return;

    [self.retryTrackerLock lock];
    self.retryTracker[url] = @(0);
    [self.retryTrackerLock unlock];
}

- (BOOL) shouldRetryRequest:(NSURLRequest*)request {
    NSString* url = request.URL.absoluteString;
    if (!url) return NO;

    [self.retryTrackerLock lock];
    NSNumber* retryCount = self.retryTracker[url];
    [self.retryTrackerLock unlock];

    return retryCount && retryCount.integerValue < kRetryLimit;
}

- (void) incrementRetryCountForRequest:(NSURLRequest*)request {
    NSString* url = request.URL.absoluteString;
    if (!url) return;

    [self.retryTrackerLock lock];
    NSNumber* currentCount = self.retryTracker[url] ?: @(0);
    self.retryTracker[url] = @(currentCount.integerValue + 1);
    [self.retryTrackerLock unlock];
}

- (void) removeFromRetryTracker:(NSURLRequest*)request {
    NSString* url = request.URL.absoluteString;
    if (!url) return;

    [self.retryTrackerLock lock];
    [self.retryTracker removeObjectForKey:url];
    [self.retryTrackerLock unlock];
}

- (void) handleSuccessfulRequest:(NSURLRequest*)request {
    NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Upload completed successfully");
    [self removeFromRetryTracker:request];
}

- (void) handleFailedRequest:(NSURLRequest*)request error:(NSError* _Nullable)error {
    if (error) {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Upload failed - %@", error.localizedDescription);
    } else {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Upload failed with unknown error");
    }

    // Check if we should retry
    if ([self shouldRetryRequest:request]) {
        [self incrementRetryCountForRequest:request];

        [self.retryQueueLock lock];
        [self.retryQueue addObject:request];
        [self.retryQueueLock unlock];

        NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Added request to retry queue");
    } else {
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Max retries reached, discarding request");
        [self removeFromRetryTracker:request];
    }
}

- (void) handleResponse:(NSURLResponse*)response request:(NSURLRequest*)request {
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    if (!httpResponse) {
        return;
    }

    NSInteger statusCode = httpResponse.statusCode;

    NSLog(@"========== Mobile Errors Response Status ==========");
    NSLog(@"Status code: %ld", (long)statusCode);
    NSLog(@"===================================================");

    NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Received response with status code: %ld", (long)httpResponse.statusCode);

    if (statusCode >= 200 && statusCode < 300) {
        // Success
        [self handleSuccessfulRequest:request];
    } else if (statusCode >= 400 && statusCode < 500) {
        // Client error - don't retry
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Client error (%ld), not retrying", (long)statusCode);
        [self removeFromRetryTracker:request];
    } else if (statusCode >= 500 && statusCode < 600) {
        // Server error - retry
        NRLOG_AGENT_ERROR(@"Mobile Errors Uploader: Server error (%ld), will retry", (long)statusCode);
        [self handleFailedRequest:request error:nil];
    } else {
        NRLOG_AGENT_WARNING(@"Mobile Errors Uploader: Unexpected status code: %ld", (long)statusCode);
        [self handleFailedRequest:request error:nil];
    }
}

#pragma mark - NSURLSessionDelegate

- (void) URLSession:(NSURLSession*)session
               task:(NSURLSessionTask*)task
didCompleteWithError:(NSError* _Nullable)error {

    NSURLRequest* request = task.originalRequest;
    if (!request) {
        return;
    }

    if (error) {
        // Network or other error occurred
        NSInteger errorCode = error.code;

        // Check if it was cancelled
        if (errorCode == NSURLErrorCancelled) {
            NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Upload was cancelled");
            [self removeFromRetryTracker:request];
            return;
        }

        [self handleFailedRequest:request error:error];
    } else if (task.response) {
        // Request completed, check status code
        [self handleResponse:task.response request:request];
    }
}

- (void) URLSession:(NSURLSession*)session
           dataTask:(NSURLSessionDataTask*)dataTask
 didReceiveResponse:(NSURLResponse*)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    // Allow the task to proceed
    completionHandler(NSURLSessionResponseAllow);
}

- (void) URLSession:(NSURLSession*)session
           dataTask:(NSURLSessionDataTask*)dataTask
     didReceiveData:(NSData*)data {

    // Log response data
    NSString* responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (responseString) {
        NSLog(@"========== Mobile Errors Response ==========");
        NSLog(@"Response body: %@", responseString);
        NSLog(@"============================================");
        NRLOG_AGENT_VERBOSE(@"Mobile Errors Uploader: Response data: %@", responseString);
    }
}

@end
