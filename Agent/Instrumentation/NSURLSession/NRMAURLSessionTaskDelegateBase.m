//
//  NSURLSessionTaskDelegateBase.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/1/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionTaskDelegateBase_Private.h"
#import "NRMANSURLConnectionSupport+private.h"
#import "NRMAURLSessionTaskOverride.h"
#import "NRMAURLSessionOverride.h"
#import "NRMAExceptionHandler.h"

@implementation NRURLSessionTaskDelegateBase

- (instancetype) initWithOriginalDelegate:(id<NSURLSessionDataDelegate>)delegate
{
    self = [super init];
    if (self) {
        _realDelegate = delegate;
    }
    return self;
}


#pragma mark - NSURLSessionDataDelegate Methods


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    @try {
        NRTimer* timer = NRMA__getTimerForSessionTask(task);
        // If timer is nil then maybe we didn't instrument the task in time, let's not record it.
        if (timer) {

            [timer stopTimer];

            if (error) {
                [NRMANSURLConnectionSupport noticeError:error
                                           forRequest:task.originalRequest
                                            withTimer:timer];
            } else {
                NSData *data = NRMA__getDataForSessionTask(task);

                [NRMANSURLConnectionSupport noticeResponse:task.response
                                              forRequest:task.originalRequest
                                               withTimer:timer
                                                 andBody:data
                                                 bytesSent:(NSUInteger)task.countOfBytesSent
                                           bytesReceived:(NSUInteger)task.countOfBytesReceived];
            }
            // Set the timer corresponding with this task to nil since we just stopped it and recorded the network request.
            NRMA__setTimerForSessionTask(task, nil);
            NRMA__setDataForSessionTask(task, nil);
        }

    } @catch(NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([self class])
                                selector:@"URLSession:task:didCompleteWithError:"];
    }
    
    if ([self.realDelegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [self.realDelegate URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NRMA__setDataForSessionTask(dataTask, data);
    if ([self.realDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [self.realDelegate URLSession:session
                             dataTask:dataTask
                       didReceiveData:data];
    }
}
@end

