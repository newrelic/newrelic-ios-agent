//
//  NRMAURLSessionGraphQLCPPHelper.m
//  Agent
//
//  Created by Mike Bruin on 10/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAURLSessionGraphQLCPPHelper.h"
#import "NRMANetworkFacade.h"
#import "NewRelicAgentInternal.h"
#import <Connectivity/Payload.hpp>
#import "NRMAHTTPUtilities+cppInterface.h"
#import "NRMAAnalytics+cppInterface.h"
#import "NewRelicInternalUtils.h"

IMP NRMAOriginal__NoticeNetworkRequest;

static NRMAURLSessionGraphQLCPPHelper* _sharedInstance;


@implementation NRMAURLSessionGraphQLCPPHelper
{
    
}

+ (NRMAURLSessionGraphQLCPPHelper*) sharedInstance {
    return _sharedInstance;
}

+ (void) startHelper {
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken,
                  ^{
        _sharedInstance = [[NRMAURLSessionGraphQLCPPHelper alloc] init];
    });
}

+ (void) noticeNetworkRequest:(NSURLRequest*)request
                     response:(NSURLResponse*)response
                    withTimer:(NRTimer*)timer
                    bytesSent:(NSUInteger)bytesSent
                bytesReceived:(NSUInteger)bytesReceived
                 responseData:(NSData*)responseData
                 traceHeaders:(NSDictionary<NSString*,NSString*>* _Nullable)traceHeaders
                       params:(NSDictionary*)params {
    [timer stopTimer];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        NSString* connectionType = [NewRelicInternalUtils getCurrentWanType];

        NRMAURLTransformer *transformer = [NewRelicAgentInternal getURLTransformer];
        NSURL *replacedURL = [transformer transformURL:request.URL];
        if(!replacedURL) {
            replacedURL = request.URL;
        }

        NRMANetworkRequestData* networkRequestData = [[NRMANetworkRequestData alloc] initWithRequestUrl:replacedURL httpMethod:[request HTTPMethod] connectionType:connectionType contentType:[NRMANetworkFacade contentType:response] bytesSent:bytesSent];
        
        [[[NRMAURLSessionGraphQLCPPHelper sharedInstance] analytics] addNetworkRequestEvent:networkRequestData
                                                                                withResponse:[[NRMANetworkResponseData alloc] initWithSuccessfulResponse:[NRMANetworkFacade statusCode:response]
                                                                                                                                           bytesReceived:bytesReceived
                                                                                                                                            responseTime:[timer timeElapsedInSeconds]]
                                                                                 withPayload:[NRMAHTTPUtilities retrievePayload:request]];
        [self sharedInstance].networkFinished = YES;
    });
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    }
    return self;
}

@end
