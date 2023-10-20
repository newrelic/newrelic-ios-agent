//
//  NRMAURLSessionGraphQLCPPHelper.h
//  Agent
//
//  Created by Mike Bruin on 10/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAAnalytics.h"

NS_ASSUME_NONNULL_BEGIN
@interface NRMAURLSessionGraphQLCPPHelper : NSObject

@property(atomic,strong) NRMAAnalytics* analytics;

@property(nonatomic) BOOL networkFinished;

+ (void) startHelper;

+ (NRMAURLSessionGraphQLCPPHelper*) sharedInstance;

+ (void) noticeNetworkRequest:(NSURLRequest*)request
                     response:(NSURLResponse*)response
                    withTimer:(NRTimer*)timer
                    bytesSent:(NSUInteger)bytesSent
                bytesReceived:(NSUInteger)bytesReceived
                 responseData:(NSData*)responseData
                 traceHeaders:(NSDictionary<NSString*,NSString*>* _Nullable)traceHeaders
                       params:(NSDictionary*)params;

@end
NS_ASSUME_NONNULL_END
