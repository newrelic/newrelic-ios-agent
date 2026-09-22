//
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMANetworkResponseData : NSObject
@property (nonatomic) NSInteger statusCode;
@property (nonatomic) NSInteger bytesReceived;
@property (nonatomic, retain) NSString* errorMessage;
@property (nonatomic, retain) NSString* appDataHeader;
@property (nonatomic, retain) NSString* encodedResponseBody;
@property (nonatomic) NSInteger networkErrorCode;

/// Apple's NSURLSessionTaskMetricsResourceFetchType for the final transaction.
/// Values: @"unknown", @"networkLoad", @"serverPush", @"localCache". nil when not captured.
@property (nonatomic, retain) NSString* resourceFetchType;

/// Underlying wire status code from the final NSURLSessionTaskTransactionMetrics.
/// Useful when Apple's URLCache rewrites a 304 to 200 in the user-visible response.
/// 0 means not captured.
@property (nonatomic) NSInteger wireStatusCode;

@property double timeInSeconds;

-(id) initWithSuccessfulResponse:(NSInteger)statusCode
                   bytesReceived:(NSInteger)bytesReceived
                    responseTime:(double)timeInSeconds;

-(id) initWithNetworkError:(NSInteger)networkErrorCode
             bytesReceived:(NSInteger)bytesReceived
              responseTime:(double)timeInSeconds
       networkErrorMessage:(NSString*)errorMessage;

-(id) initWithHttpError:(NSUInteger)statusCode
          bytesReceived:(NSInteger)bytesReceived
           responseTime:(double)timeInSeconds
    networkErrorMessage:(NSString*)errorMessage
    encodedResponseBody:(NSString*)encodedResponseBody
          appDataHeader:(NSString*)appDataHeader;

-(void) dealloc;

@end
