//
//  NRMAWKFakeNavigationAction.m
//  Agent_iOS
//
//  Created by Mike Bruin on 3/20/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAWKWebViewNavigationDelegate.h"
#import "NRMAWKFakeNavigationAction.h"
#import "NRTimer.h"
#import <WebKit/WebKit.h>


#pragma mark NRMAWKFakeNavigationAction

@implementation NRMAWKFakeNavigationAction

- (instancetype)initWith:(NSURLRequest*) request {
    self = [super init];
    if (self) {
        self.urlRequest = request;
    }
    return self;
}

- (void) decisionHandler:(WKNavigationActionPolicy) policy {
    self.receivedPolicy = policy;
}

@end

#pragma mark NRMAWKFakeNavigationResponse

@implementation NRMAWKFakeNavigationResponse

- (instancetype)initWith:(NSURLRequest*) request {
    self = [super init];
    if (self) {
        self.urlRequest = request;
    }
    return self;
}

- (void) decisionHandler:(WKNavigationResponsePolicy) policy {
    self.receivedPolicy = policy;
}

@end

#pragma mark NRMAWKFakeURLAuthenticationChallenge

@implementation NRMAWKFakeURLAuthenticationChallenge
- (instancetype)initWith:(NSURLRequest*) request {
    if (self) {
        self.urlRequest = request;
    }
    return self;
}

- (void) completionHandler:(NSURLSessionAuthChallengeDisposition)disposition withCredential: (NSURLCredential*)credential  {
    self.authenticationChallengeDisposition = disposition;
    self.credential = credential;
}

@end
