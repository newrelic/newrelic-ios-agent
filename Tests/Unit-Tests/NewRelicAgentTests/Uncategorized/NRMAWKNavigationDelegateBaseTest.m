//
//  NRMAWKNavigationDelegateBaseTest.m
//  NewRelicAgent
//
//  Created by Austin Washington on 7/26/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "NRMAWKWebViewNavigationDelegate.h"
#import "NRTimer.h"
#import <WebKit/WebKit.h>
#import "NRMAWKFakeNavigationAction.h"

@interface NRMAWKNavigationDelegateWithDelegateFunctions : NSObject <WKNavigationDelegate>
@end

@interface NRWKNavigationDelegateBase ()
- (instancetype) initWithOriginalDelegate:(NSObject<WKNavigationDelegate>* __nullable __weak)delegate;
+ (NSURL*) navigationURL:(WKNavigation*) nav;
+ (NRTimer*) navigationTimer:(WKNavigation*) nav;
+ (void) navigation:(WKNavigation*)nav setURL:(NSURL*)url;
+ (void) navigation:(WKNavigation*)nav setTimer:(NRTimer*)timer;
@end

@interface NRMAWKNavigationDelegateBaseTest : XCTestCase <WKNavigationDelegate>
@property(strong) NRTimer* timer;
@property(strong) NSURL* url;
@property(strong) WKNavigation* web;
@property(strong) NRMAWKWebViewNavigationDelegate* navBase;
@property(strong) WKWebView* webView;

@property(strong) NRMAWKWebViewNavigationDelegate* navBaseWithDelegateFunction;
@property(strong) NRMAWKNavigationDelegateWithDelegateFunctions* delegateFunctions;
@property(strong) WKWebView* webViewWithDelegateFunction;

@end

@implementation NRMAWKNavigationDelegateBaseTest

- (void)setUp {
    [super setUp];
    self.navBase = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:self];
    self.web = [[WKNavigation alloc] init];
    self.url = [NSURL URLWithString: @"localhost"];
    self.timer = [[NRTimer alloc] init];
    self.webView = [[WKWebView alloc] init];
    self.webView.navigationDelegate = _navBase;
    
    self.delegateFunctions = [[NRMAWKNavigationDelegateWithDelegateFunctions alloc] init];
    self.navBaseWithDelegateFunction = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:_delegateFunctions];
    self.webViewWithDelegateFunction = [[WKWebView alloc] init];
    self.webViewWithDelegateFunction.navigationDelegate = _navBaseWithDelegateFunction;
}

- (void)tearDown {
    [super tearDown];
}

- (void) testNilParameterPassing {
    @autoreleasepool {
        XCTAssertNoThrow([NRWKNavigationDelegateBase navigation:nil setURL:_url], @"");
        XCTAssertNil([NRWKNavigationDelegateBase navigationURL:_web]);
        
        XCTAssertNoThrow([NRWKNavigationDelegateBase navigation:nil setTimer:_timer], @"");
        XCTAssertNil([NRWKNavigationDelegateBase navigationTimer:_web]);
        //[NRWKNavigationDelegateBase navigationTimer:_web];
    }
}

- (void) testImpersonation {
    @autoreleasepool {
        XCTAssertTrue([self.navBase isKindOfClass:[self class]]);
        XCTAssertTrue([self.navBase isKindOfClass:[NRWKNavigationDelegateBase class]]);
    }
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

- (void) testDecidePolicyForNavigationActionWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeNavigationAction *testAction = [[NRMAWKFakeNavigationAction alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationAction:testAction decisionHandler:^(WKNavigationActionPolicy policy){
        [testAction decisionHandler:policy];
    }];
    
    XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    
    if (@available(iOS 13.0, *)) {
        [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationAction:testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
            [testAction decisionHandler:policy];
        }];
        XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    }
}

- (void) testDidReceiveAuthenticationChallengeWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeURLAuthenticationChallenge *testChallenge = [[NRMAWKFakeURLAuthenticationChallenge alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction didReceiveAuthenticationChallenge:[[NSURLAuthenticationChallenge alloc] init] completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential){
        [testChallenge completionHandler:disposition withCredential:credential];
    }];
    
    XCTAssertNil(testChallenge.credential);
    XCTAssertEqual(testChallenge.authenticationChallengeDisposition, NSURLSessionAuthChallengePerformDefaultHandling);
}

- (void) testDecidePolicyForNavigationResponseWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"localhost"]];
    
    NRMAWKFakeNavigationResponse *testResponse = [[NRMAWKFakeNavigationResponse alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationResponse:testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

@end

@implementation NRMAWKNavigationDelegateWithDelegateFunctions
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
