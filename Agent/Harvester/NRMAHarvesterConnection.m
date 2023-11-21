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
#import <time.h>
#import "NRMAHarvesterConnection+GZip.h"
#import "NRMASupportMetricHelper.h"

@implementation NRMAHarvesterConnection
@synthesize connectionInformation = _connectionInformation;
- (id) init
{
    self = [super init];
    if (self) {
        self.harvestSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        self.offlineStorage = [[NRMAOfflineStorage alloc] initWithEndpoint:@"data"];
    }
    return self;
}

-(void) sendOfflineStorage {
    NSArray<NSData *> * offlineData = [self.offlineStorage getAllOfflineData];
    NSLog(@"%@", offlineData);
    
    [offlineData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSData *jsonData = (NSData *)obj;
        
        NSURLRequest* post = [self createDataPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
        if (post == nil) {
            NRLOG_ERROR(@"Failed to create data POST");
            return;
        }
        
        NRLOG_VERBOSE(@"NEWRELIC - OFFLINE DATA: %@", jsonData);
        
        [self send:post];
    }];
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
    NRMAHarvestResponse* harvestResponse = [[NRMAHarvestResponse alloc] init];
    __block NSHTTPURLResponse* response;
    __block NSError* error;
    __block NSData* data;

    __block dispatch_semaphore_t harvestRequestSemaphore = dispatch_semaphore_create(0);
    
    BOOL wasCompressed = [post.allHTTPHeaderFields[kNRMAContentEncodingHeader] isEqualToString:kNRMAGZipHeader];
    long size = wasCompressed ? [post.allHTTPHeaderFields[kNRMAActualSizeHeader] longLongValue] : [post.HTTPBody length];
    if (size > kNRMAMaxPayloadSizeLimit) {
        NSString* subDest = [[post URL] lastPathComponent];
        NRLOG_ERROR(@"Unable to send %@ harvest because payload is larger than 1 MB.", subDest);
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:subDest];
        harvestResponse.statusCode = ENTITY_TOO_LARGE;
        return harvestResponse;
    }
    
    NRLOG_VERBOSE(@"NEWRELIC - REQUEST: %@", post);
    NRLOG_VERBOSE(@"NEWRELIC - REQUEST BODY: %@", post.HTTPBody);

    NSData *initialReqBody = [post.HTTPBody copy];
    NSMutableURLRequest *modifiedRequest = [post mutableCopy];
    [modifiedRequest setHTTPBody:nil];

    [[self.harvestSession uploadTaskWithRequest:modifiedRequest
                                       fromData:initialReqBody
                              completionHandler:^(NSData* responseBody, NSURLResponse* bresponse, NSError* berror){
        @autoreleasepool {
            data = responseBody;
            error = berror;
            response = (NSHTTPURLResponse*)bresponse;
            dispatch_semaphore_signal(harvestRequestSemaphore);
            
            NRLOG_VERBOSE(@"NEWRELIC CONNECT - RESPONSE: %@", [response debugDescription]);
            
            // Enqueue Data Usage Supportability Metric for /data or /connect if the harvest request was successful.
            if (!error) {
                BOOL wasCompressed = [post.allHTTPHeaderFields[kNRMAContentEncodingHeader] isEqualToString:kNRMAGZipHeader];
                long size = wasCompressed ? [post.allHTTPHeaderFields[kNRMAActualSizeHeader] longLongValue] : [post.HTTPBody length];
                NSString* subDest = [[post URL] lastPathComponent];

                [NRMASupportMetricHelper enqueueDataUseMetric:subDest size:size received:responseBody.length];
            }
        }
    }] resume];

    dispatch_semaphore_wait(harvestRequestSemaphore, dispatch_time(DISPATCH_TIME_NOW,  (uint64_t)(post.timeoutInterval*(double)(NSEC_PER_SEC))));
    
    if (error) {
        NRLOG_ERROR(@"NEWRELIC CONNECT - Failed to retrieve collector response: %@",error);

#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        @try {
#endif
            [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:kNRSupportabilityPrefix@"/Collector/ResponseErrorCodes/%"NRMA_NSI,[error code]]
                                                            value:@1
                                                            scope:@""]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        } @catch (NSException* exception) {
            [NRMAExceptionHandler logException:exception
                                         class:NSStringFromClass([self class])
                                      selector:NSStringFromSelector(_cmd)];
        }
#endif
        harvestResponse.error = error;
    }

    harvestResponse.statusCode = (int)response.statusCode;
    harvestResponse.responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NRLOG_VERBOSE(@"NEWRELIC CONNECT - RESPONSE DATA: %@", harvestResponse.responseBody);
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
        NRLOG_ERROR(@"Failed to generate JSON");
        return  nil;
    }
    NSURLRequest* post = [self createConnectPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    if (post == nil) {
        NRLOG_ERROR(@"Failed to create connect POST");
        return nil;
    }
    
    NRLOG_VERBOSE(@"NEWRELIC - CONNECTION BODY: %@", self.connectionInformation.JSONObject);
    
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
        NRLOG_ERROR(@"Failed to generate JSON");
        return nil;
    }
    
    NRMAReachability* r = [NewRelicInternalUtils reachability];
    @synchronized(r) {
        NRMANetworkStatus status = [r currentReachabilityStatus];
        
        if(status == NotReachable){
            [self.offlineStorage persistDataToDisk:jsonData];
            return nil;
        } else {
            [self sendOfflineStorage];
        }
    }
        
    NSURLRequest* post = [self createDataPost:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    if (post == nil) {
        NRLOG_ERROR(@"Failed to create data POST");
        return nil;
    }
    
    NRLOG_VERBOSE(@"NEWRELIC - HARVEST DATA: %@", harvestable.JSONObject);
    
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
    return [self collectorHostURL:(NSString*)kCOLLECTOR_CONNECT_URI];
}

- (NSString*) collectorHostDataURL
{
    return [self collectorHostURL:(NSString*)kCOLLECTOR_DATA_URL];
}

- (NSString*) collectorHostURL:(NSString*)resource
{
    NSString* protocol = self.useSSL ? @"https://":@"http://";
    return [NSString stringWithFormat:@"%@%@%@",protocol,self.collectorHost,resource];
}

@end
