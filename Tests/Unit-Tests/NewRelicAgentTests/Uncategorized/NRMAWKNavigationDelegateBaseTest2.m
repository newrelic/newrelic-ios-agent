//
//  NRMAWKNavigationDelegateBaseTest2.m
//  Agent_iOS
//
//  Created by Mike Bruin on 3/21/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "NRMAWKWebViewNavigationDelegate.h"
#import "NRTimer.h"
#import <WebKit/WebKit.h>
#import "NRMAWKFakeNavigationAction.h"

@interface NRWKNavigationDelegateBase ()
- (instancetype) initWithOriginalDelegate:(NSObject<WKNavigationDelegate>* __nullable __weak)delegate;
@end

@interface NRMAWKNavigationDelegateBaseTest2 : XCTestCase <WKNavigationDelegate>
@property(strong) NSURL* url;
@property(strong) WKNavigation* web;
@property(strong) NRMAWKWebViewNavigationDelegate* navBase;
@property(strong) WKWebView* webView;


@end

@implementation NRMAWKNavigationDelegateBaseTest2

- (void)setUp {
    [super setUp];
    self.navBase = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:self];
    self.web = [[WKNavigation alloc] init];
    self.url = [NSURL URLWithString: @"localhost"];
    self.webView = [[WKWebView alloc] init];
    self.webView.navigationDelegate = _navBase;
}

- (void)tearDown {
    [super tearDown];
}

- (void) testDecidePolicyForNavigationAction {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeNavigationAction *testAction = [[NRMAWKFakeNavigationAction alloc] initWith:url];
    
    [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationAction:testAction decisionHandler:^(WKNavigationActionPolicy policy){
        [testAction decisionHandler:policy];
    }];
    
    XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    
    if (@available(iOS 13.0, *)) {
        [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationAction:testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
            [testAction decisionHandler:policy];
        }];
        XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    }
}

- (void) testDidReceiveAuthenticationChallenge {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeURLAuthenticationChallenge *testChallenge = [[NRMAWKFakeURLAuthenticationChallenge alloc] initWith:url];
    
    [self.webView.navigationDelegate webView:self.webView didReceiveAuthenticationChallenge:[[NSURLAuthenticationChallenge alloc] init] completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential){
        [testChallenge completionHandler:disposition withCredential:credential];
    }];
    
    XCTAssertNil(testChallenge.credential);
    XCTAssertEqual(testChallenge.authenticationChallengeDisposition, NSURLSessionAuthChallengePerformDefaultHandling);
}

- (void) testDecidePolicyForNavigationResponse {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeNavigationResponse *testResponse = [[NRMAWKFakeNavigationResponse alloc] initWith:url];
    
    [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationResponse:testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

#pragma mark Delegate Functions

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler API_AVAILABLE(ios(13.0))
{
    decisionHandler(WKNavigationActionPolicyAllow, preferences);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

@end
