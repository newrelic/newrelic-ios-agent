//
//  NRMAWKFakeNavigationAction.h
//  Agent
//
//  Created by Mike Bruin on 3/20/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <WebKit/WebKit.h>

#pragma mark NRMAWKFakeNavigationAction

@interface NRMAWKFakeNavigationAction : NSObject
@property(strong) NSURLRequest* urlRequest;
@property WKNavigationActionPolicy receivedPolicy;

- (instancetype)initWith:(NSURLRequest*) request;
- (void)decisionHandler:(WKNavigationActionPolicy) policy;
@end

#pragma mark NRMAWKFakeNavigationResponse

@interface NRMAWKFakeNavigationResponse : NSObject
@property(strong) NSURLRequest* urlRequest;
@property WKNavigationResponsePolicy receivedPolicy;

- (instancetype)initWith:(NSURLRequest*) request;
- (void) decisionHandler:(WKNavigationResponsePolicy) policy;
@end


#pragma mark NRMAWKFakeURLAuthenticationChallenge

@interface NRMAWKFakeURLAuthenticationChallenge : NSObject
@property(strong) NSURLRequest* urlRequest;
@property(strong) NSURLCredential* credential;
@property NSURLSessionAuthChallengeDisposition authenticationChallengeDisposition;

- (instancetype)initWith:(NSURLRequest*) request;
- (void) completionHandler:(NSURLSessionAuthChallengeDisposition)disposition withCredential: (NSURLCredential*)credential;
@end
