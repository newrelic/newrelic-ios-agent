//
//  NRMAHarvesterConnection.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NewRelicInternalUtils.h"
#import "NRMAExceptionHandler.h"
#import "NRMAMeasurements.h"
#import <zlib.h>
#import "NRMATaskQueue.h"
#import "Constants.h"
#import <time.h>
#import "NRMAHarvesterConnection+GZip.h"
#import "NRMASupportMetricHelper.h"
#import "NRMAFlags.h"
#import "NewRelicAgentInternal.h"
#import "NRMARetryOrchestrator.h"

@implementation NRMAHarvesterConnection
@synthesize connectionInformation = _connectionInformation;
- (id) init
{
    self = [super init];
    if (self) {
        self.harvestSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        self.offlineStorage = [[NRMAOfflineStorage alloc] initWithEndpoint:@"data"];

        // Initialize retry configuration with defaults
        self.maxForegroundRetries = 5;
        self.maxBackgroundRetries = 1;
        self.initialRetryDelay = 1.0;
        self.maxRetryDelay = 16.0;

        self.retryOrchestrator = [[NRMARetryOrchestrator alloc] initWithInitialDelay:self.initialRetryDelay
                                                                             maxDelay:self.maxRetryDelay];
    }
    return self;
}

- (NSArray<NSData *> *) getOfflineData {
    return [self.offlineStorage getAllOfflineData:NO];
}

-(void) sendOfflineStorage {
    if (![NRMAFlags shouldEnableOfflineStorage]) {
        [NRMAOfflineStorage clearAllOfflineDirectories];
        return;
    }
    NSArray<NSData *> * offlineData = [self.offlineStorage getAllOfflineData:YES];
    if(offlineData.count == 0){
        return;
    }
    NRLOG_AGENT_VERBOSE(@"Number of offline data posts: %lu", (unsigned long)offlineData.count);
    __block NSUInteger totalSize = 0;
    [offlineData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSData *jsonData = (NSData *)obj;
        
        NSURLRequest* post = [self createDataPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
        if (post == nil) {
            NRLOG_AGENT_ERROR(@"Failed to create data POST");
            return;
        }

        NRMAHarvestResponse* response = [self send:post];
        
        if([NRMAOfflineStorage checkErrorToPersist:response.error]) {
            [_offlineStorage persistDataToDisk:jsonData];
        } else {
            totalSize += [post.HTTPBody length];
        }
    }];
    [NRMASupportMetricHelper enqueueOfflinePayloadMetric:totalSize];
}

- (NSURLRequest*) createPostWithURI:(NSString*)url message:(NSString*)message
{
    NSMutableURLRequest * postRequest = [super newPostWithURI:url];

    NSString* contentEncoding = message.length <= 512 ? kNRMAIdentityHeader : kNRMAGZipHeader;

    [postRequest addValue:contentEncoding forHTTPHeaderField:kNRMAContentEncodingHeader];

    if (self.serverTimestamp != 0) {
        [postRequest addValue:[NSString stringWithFormat:@"%lld",self.serverTimestamp]
           forHTTPHeaderField:(NSString*)kCONNECT_TIME_HEADER];
    }

    if (self.requestHeadersMap != nil && [self.requestHeadersMap count] > 0) {
        for (NSString *key in self.requestHeadersMap) {
            NSString* value = [self.requestHeadersMap objectForKey:key];
            [postRequest addValue:value forHTTPHeaderField:key];
        }
    }
  
    NSData* messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    unsigned long size = [messageData length];
    [postRequest setValue:[NSString stringWithFormat:@"%lu", size] forHTTPHeaderField:kNRMAActualSizeHeader];

    if ([contentEncoding isEqualToString:kNRMAGZipHeader]) {
        messageData = [NRMAHarvesterConnection gzipData:messageData];
    }
    [postRequest setHTTPBody:messageData];
    
    return postRequest;
}

- (NRMAHarvestResponse*) send:(NSURLRequest *)post
{
    // Check payload size before attempting any retries
    BOOL wasCompressed = [post.allHTTPHeaderFields[kNRMAContentEncodingHeader] isEqualToString:kNRMAGZipHeader];
    long size = wasCompressed ? [post.allHTTPHeaderFields[kNRMAActualSizeHeader] longLongValue] : [post.HTTPBody length];
    if (size > kNRMAMaxPayloadSizeLimit) {
        NSString* subDest = [[post URL] lastPathComponent];
        NRLOG_AGENT_ERROR(@"Unable to send %@ harvest because payload is larger than 1 MB.", subDest);
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:subDest];
        NRMAHarvestResponse* harvestResponse = [[NRMAHarvestResponse alloc] init];
        harvestResponse.statusCode = ENTITY_TOO_LARGE;
        return harvestResponse;
    }

    NSInteger maxRetries = [self maxRetriesForCurrentState];
    NRLOG_AGENT_DEBUG(@"❤️ NEWRELIC - REQUEST (attempt 1/%ld): %@", (long)(maxRetries + 1), post);
    NRLOG_AGENT_DEBUG(@"❤️ NEWRELIC - REQUEST BODY: %@", post.HTTPBody);

    // Prepare request data once; reused across retry attempts.
    NSData *initialReqBody = [post.HTTPBody copy];
    NSMutableURLRequest *modifiedRequest = [post mutableCopy];
    [modifiedRequest setHTTPBody:nil];

    // Sync executeRequest: wraps the async URLSession upload task with a semaphore so
    // onResponse is called synchronously before the block returns. This keeps send:
    // synchronous for callers in NRMAHarvester.
    NSURLSession *session = self.harvestSession;
    NRMAExecuteRequestBlock executeRequest = ^(void (^onResponse)(NSHTTPURLResponse*, NSData*, NSError*)) {
        __block NSHTTPURLResponse *httpResponse = nil;
        __block NSData *responseData = nil;
        __block NSError *responseError = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        [[session uploadTaskWithRequest:modifiedRequest
                               fromData:initialReqBody
                      completionHandler:^(NSData *body, NSURLResponse *response, NSError *error) {
            @autoreleasepool {
                httpResponse = (NSHTTPURLResponse *)response;
                responseData = body;
                responseError = error;
                dispatch_semaphore_signal(sem);

                NRLOG_AGENT_DEBUG(@"NEWRELIC CONNECT - RESPONSE: %@", [response debugDescription]);

                if (!error) {
                    BOOL compressed = [post.allHTTPHeaderFields[kNRMAContentEncodingHeader] isEqualToString:kNRMAGZipHeader];
                    long sz = compressed ? [post.allHTTPHeaderFields[kNRMAActualSizeHeader] longLongValue] : [post.HTTPBody length];
                    [NRMASupportMetricHelper enqueueDataUseMetric:[[post URL] lastPathComponent] size:sz received:body.length];
                }
            }
        }] resume];

        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (uint64_t)(post.timeoutInterval * (double)NSEC_PER_SEC)));

        if (responseError) {
            NRLOG_AGENT_ERROR(@"NEWRELIC CONNECT - Failed to retrieve collector response: %@", responseError);
#ifndef DISABLE_NRMA_EXCEPTION_WRAPPER
            @try {
#endif
                [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRSupportabilityPrefix@"/Collector/ResponseErrorCodes/%"NRMA_NSI, [responseError code]]
                                                                value:@1
                                                                scope:@""]];
#ifndef DISABLE_NRMA_EXCEPTION_WRAPPER
            } @catch (NSException *exception) {
                [NRMAExceptionHandler logException:exception
                                             class:NSStringFromClass([self class])
                                          selector:@"send:"];
            }
#endif
        }

        onResponse(httpResponse, responseData, responseError);
    };

    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = ^BOOL(NSHTTPURLResponse *response, NSError *error) {
        NRMAHarvestResponse *hr = [[NRMAHarvestResponse alloc] init];
        hr.statusCode = (int)response.statusCode;
        hr.error = error;
        return [self shouldRetryForResponse:hr];
    };

    // Because executeRequest and waitForDelay are both synchronous, the orchestrator's
    // recursive callback chain fires entirely on the calling thread before
    // executeWithMaxRetries:... returns, so harvestResponse is always set.
    __block NRMAHarvestResponse *harvestResponse = nil;

    [self.retryOrchestrator executeWithMaxRetries:maxRetries
                                   executeRequest:executeRequest
                                      shouldRetry:shouldRetry
                                     waitForDelay:[NRMARetryOrchestrator syncWaitForDelay]
                                       completion:^(NSHTTPURLResponse *response, NSData *data, NSError *error, NSInteger retryCount) {
        harvestResponse = [[NRMAHarvestResponse alloc] init];
        harvestResponse.statusCode = (int)response.statusCode;
        harvestResponse.responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        harvestResponse.error = error;
        NRLOG_AGENT_DEBUG(@"NEWRELIC CONNECT - RESPONSE DATA: %@", harvestResponse.responseBody);

        if (retryCount > 0) {
            [self recordRetryMetric:retryCount success:[harvestResponse isOK]];
        }
    }];

    return harvestResponse;
}

- (NRMAHarvestResponse*) sendConnect
{
    if (self.connectionInformation == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:nil userInfo:nil];
    }
    NSError* error=nil;
    NSData* jsonData = [NRMAJSON dataWithJSONABLEObject:self.connectionInformation options:0 error:&error];
    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to generate JSON");
        return  nil;
    }
    NSURLRequest* post = [self createConnectPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    if (post == nil) {
        NRLOG_AGENT_ERROR(@"Failed to create connect POST");
        return nil;
    }
    
    NRLOG_AGENT_VERBOSE(@"NEWRELIC - CONNECTION BODY: %@", self.connectionInformation.JSONObject);
    
    return [self send:post];
}

- (NRMAConnectInformation*) connectionInformation {
    return _connectionInformation;
}

- (void) setConnectionInformation:(NRMAConnectInformation *)connectionInformation {
    _connectionInformation = connectionInformation;
    self.applicationVersion = connectionInformation.applicationInformation.appVersion;
}

- (NRMAHarvestResponse*) sendData:(NRMAHarvestable *)harvestable
{
    if (harvestable == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:nil
                                     userInfo:nil];
    }
    NSError* error = nil;
    NSData* jsonData = [NRMAJSON dataWithJSONABLEObject:harvestable options:0 error:&error];
    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to generate JSON");
        return nil;
    }
        
    NSURLRequest* post = [self createDataPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    if (post == nil) {
        NRLOG_AGENT_ERROR(@"Failed to create data POST");
        return nil;
    }
    
    NRLOG_AGENT_VERBOSE(@"NEWRELIC - HARVEST DATA: %@", harvestable.JSONObject);
    
    return [self send:post];
}

- (NSURLRequest*) createConnectPost:(NSString *)message
{
    return [self createPostWithURI:[self collectorConnectURL] message:message];
}

- (NSURLRequest*) createDataPost:(NSString *)message
{
    return [self createPostWithURI:[self collectorHostDataURL] message:message];
}
- (NSString*) collectorConnectURL
{
    return [self collectorHostURL:(NSString*)kNRMA_Collector_connect_url];
}

- (NSString*) collectorHostDataURL
{
    return [self collectorHostURL:(NSString*)kNRMA_Collector_data_url];
}

- (NSString*) collectorHostURL:(NSString*)resource
{
    NSString* protocol = self.useSSL ? @"https://":@"http://";
    return [NSString stringWithFormat:@"%@%@%@",protocol,self.collectorHost,resource];
}

- (void) setMaxOfflineStorageSize:(NSUInteger) size {
    [_offlineStorage setMaxOfflineStorageSize:size];
}

#pragma mark - Retry Logic Helper Methods

- (NSInteger) maxRetriesForCurrentState {
#if TARGET_OS_WATCH
    WKApplicationState state = [NewRelicAgentInternal sharedInstance].currentApplicationState;
    return (state == WKApplicationStateBackground) ? self.maxBackgroundRetries : self.maxForegroundRetries;
#else
    UIApplicationState state = [NewRelicAgentInternal sharedInstance].currentApplicationState;
    return (state == UIApplicationStateBackground) ? self.maxBackgroundRetries : self.maxForegroundRetries;
#endif
}

- (BOOL) shouldRetryForResponse:(NRMAHarvestResponse*)response {
    // Retry on network errors (timeout, no connection, DNS failure, etc.)
    if (response.error != nil && [NRMAOfflineStorage checkErrorToPersist:response.error]) {
        return YES;
    }

    // Retry on specific HTTP status codes (rate limit and server errors)
    NSInteger status = response.statusCode;
    if (status == 429 || status == 500 || status == 502 || status == 503 || status == 504) {
        return YES;
    }

    return NO;
}


- (void) recordRetryMetric:(NSInteger)attemptCount success:(BOOL)success {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        // Record retry count metric
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRSupportabilityPrefix@"/Collector/Retry/Count"]
                                                        value:@(attemptCount)
                                                        scope:@""]];

        // Record success or failure metric
        NSString* resultMetric = success ? kNRSupportabilityPrefix@"/Collector/Retry/Success" : kNRSupportabilityPrefix@"/Collector/Retry/Failed";
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:resultMetric
                                                        value:@1
                                                        scope:@""]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:NSStringFromSelector(_cmd)];
    }
#endif
}

@end
