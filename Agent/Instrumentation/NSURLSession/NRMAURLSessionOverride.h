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
#define kNRFetchTypeAssociatedObject @"com.NewRelic.NRSessionTask.FetchType"
#define kNRWireStatusAssociatedObject @"com.NewRelic.NRSessionTask.WireStatus"
#define kNRWireBytesAssociatedObject @"com.NewRelic.NRSessionTask.WireBytes"


NSURLSession* NRMAOverride__sessionWithConfiguration_delegate_delegateQueue(id self,SEL _cmd,NSURLSessionConfiguration* configuration,id<NSURLSessionDelegate>delegate,NSOperationQueue* queue);
NSURLSession* NRMAOverride__sessionWithConfiguration(id self, SEL _cmd, NSURLSessionConfiguration* configuration);
NSURLSession* NRMAOverride__sharedSession(id self, SEL _cmd);

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

NSString* NRMA__getFetchTypeForSessionTask(NSURLSessionTask* task);
void NRMA__setFetchTypeForSessionTask(NSURLSessionTask* task, NSString* fetchType);
NSInteger NRMA__getWireStatusForSessionTask(NSURLSessionTask* task);
void NRMA__setWireStatusForSessionTask(NSURLSessionTask* task, NSInteger wireStatus);
int64_t NRMA__getWireBytesForSessionTask(NSURLSessionTask* task);
void NRMA__setWireBytesForSessionTask(NSURLSessionTask* task, int64_t wireBytes);

@interface NRMAURLSessionOverride : NSObject
+ (void) beginInstrumentation;
+ (void) deinstrument;
@end
