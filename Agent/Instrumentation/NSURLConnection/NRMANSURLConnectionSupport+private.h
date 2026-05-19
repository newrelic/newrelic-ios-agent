//
//  NRMANSURLConnectionSupport+private.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/21/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMANSURLConnectionSupport.h"
#import "NRTimer.h"


@interface NRMANSURLConnectionSupport (private)
+ (void)noticeResponse:(NSURLResponse *)response
forRequest:(NSURLRequest *)request
withTimer:(NRTimer *)timer
andBody:(NSData *)body
bytesSent:(NSUInteger)sent
bytesReceived:(NSUInteger)received;

+ (void)noticeResponse:(NSURLResponse *)response
forRequest:(NSURLRequest *)request
withTimer:(NRTimer *)timer
andBody:(NSData *)body
bytesSent:(NSUInteger)sent
bytesReceived:(NSUInteger)received
resourceFetchType:(NSString *)resourceFetchType
wireStatusCode:(NSInteger)wireStatusCode;

+ (void)noticeResponse:(NSURLResponse *)response
forRequest:(NSURLRequest *)request
withTimer:(NRTimer *)timer
andBody:(NSData *)body
bytesSent:(NSUInteger)sent
bytesReceived:(NSUInteger)received
resourceFetchType:(NSString *)resourceFetchType
wireStatusCode:(NSInteger)wireStatusCode
wireBytesReceived:(int64_t)wireBytesReceived;

+ (void)noticeError:(NSError*)error
         forRequest:(NSURLRequest *)request
          withTimer:(NRTimer *)timer;
@end
