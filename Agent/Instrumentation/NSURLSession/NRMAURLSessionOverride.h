//
//  NRMAURLSessionDataTaskOverride.h
//  NSURLSessionExperiment
//
//  Created by Bryce Buchanan on 3/14/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRTimer.h"

#define kNRTimerAssociatedObject @"com.NewRelic.NRSessionTask.Timer"
#define kNRSessionDataAssociatedObject @"com.NewRelic.NRSessionTask.Data"
// Marks whether a valid NSURLCache entry existed for the request at the moment the
// task was created. Combined with countOfBytesReceived == 0 at completion this
// reliably identifies responses served from NSURLCache rather than the network.
#define kNRPreflightCacheHitKey @"com.NewRelic.NRSessionTask.PreflightCacheHit"


NSURLSession* NRMAOverride__sessionWithConfiguration_delegate_delegateQueue(id self,SEL _cmd,NSURLSessionConfiguration* configuration,id<NSURLSessionDelegate>delegate,NSOperationQueue* queue);

NSURLSessionTask* NRMAOverride__dataTaskWithRequest(id self, SEL _cmd, NSURLRequest* request);
NSURLSessionTask* NRMAOverride__dataTaskWithURL(id self, SEL _cmd, NSURL* url);
NSURLSessionTask* NRMAOverride__dataTaskWithURL_completionHandler(id self, SEL _cmd, NSURL* url, void (^completionHandler)(NSData*,NSURLResponse*,NSError*));
NSURLSessionTask* NRMAOverride__dataTaskWithRequest_completionHandler(id self, SEL _cmd,NSURLRequest* request , void (^completionHandler)(NSData*,NSURLResponse*,NSError*));


NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromFile_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSURL* fileURL, void (^completionHandler)(NSData*,NSURLResponse*,NSError*));
NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromFile(id self, SEL _cmd,NSURLRequest* request,NSURL* fileURL);
NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromData_completionHandler(id self, SEL _cmd, NSURLRequest* request, NSData* bodyData, void (^completionHandler)(NSData*,NSURLResponse*,NSError*));
NSURLSessionTask* NRMAOverride__uploadTaskWithRequest_fromData(id self, SEL _cmd, NSURLRequest* request, NSData* data);
NSURLSessionTask* NRMAOverride__uploadTaskWithStreamedRequest(id self, SEL _cmd, NSURLRequest* request);

void NRMA__recordTask(NSURLSessionTask* task, NSData* data, NSURLResponse* response, NSError* error);
NRTimer* NRMA__getTimerForSessionTask(NSURLSessionTask* task);
NSData* NRMA__getDataForSessionTask(NSURLSessionTask* task);
void NRMA__setDataForSessionTask(NSURLSessionTask* task, NSData* data);
void NRMA__setTimerForSessionTask(NSURLSessionTask* task, NRTimer* timer);
// Returns YES when the response was served from NSURLCache rather than the network.
// Requires NRMA__markPreflightCacheHit to have been called when the task was created.
BOOL NRMA__isURLCacheHit(NSURLSessionTask *task, NSData *data);

@interface NRMAURLSessionOverride : NSObject
+ (void) beginInstrumentation;
+ (void) deinstrument;
@end
