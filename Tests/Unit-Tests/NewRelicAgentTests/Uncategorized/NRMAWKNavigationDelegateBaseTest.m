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
#import "NRMATaskQueue.h"
#import "NRMeasurementConsumerHelper.h"
#import "NRMAMeasurements.h"
#import "NRMAHTTPTransactionMeasurement.h"

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@interface NRMAWKNavigationDelegateWithDelegateFunctions : NSObject <WKNavigationDelegate>
@end

@interface NRMAWKNavigationDelegateWithOldDelegateFunction : NSObject <WKNavigationDelegate>
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
@property(strong) NRMAWKNavigationDelegateWithOldDelegateFunction* oldDelegateFunction;
@property(strong) WKWebView* webViewWithDelegateFunction;
@property(strong) WKNavigation* navigationItem;

@property(strong) NRMAMeasurementConsumerHelper* helper;


@end

@implementation NRMAWKNavigationDelegateBaseTest

- (void)setUp {
    [super setUp];
    self.navBase = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:self];
    self.web = [[WKNavigation alloc] init];
    self.url = [NSURL URLWithString: @"http://localhost/"];
    self.timer = [[NRTimer alloc] init];
    self.webView = [[WKWebView alloc] init];
    self.webView.navigationDelegate = _navBase;
    
    self.delegateFunctions = [[NRMAWKNavigationDelegateWithDelegateFunctions alloc] init];
    self.navBaseWithDelegateFunction = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:_delegateFunctions];
    self.webViewWithDelegateFunction = [[WKWebView alloc] init];
    self.webViewWithDelegateFunction.navigationDelegate = _navBaseWithDelegateFunction;
    self.navigationItem = [[WKNavigation alloc]init];
    
    [NRMATaskQueue clear];

    self.helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_HTTPTransaction];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:self.helper];

}

- (void)tearDown {
    [NRMAMeasurements removeMeasurementConsumer:self.helper];
    self.helper = nil;
    [NRMAMeasurements shutdown];
    
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
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
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
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeURLAuthenticationChallenge *testChallenge = [[NRMAWKFakeURLAuthenticationChallenge alloc] initWith:url];
    
    [self.webView.navigationDelegate webView:self.webView didReceiveAuthenticationChallenge:[[NSURLAuthenticationChallenge alloc] init] completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential){
        [testChallenge completionHandler:disposition withCredential:credential];
    }];
    
    XCTAssertNil(testChallenge.credential);
    XCTAssertEqual(testChallenge.authenticationChallengeDisposition, NSURLSessionAuthChallengePerformDefaultHandling);
}

- (void) testDecidePolicyForNavigationResponse {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeNavigationResponse *testResponse = [[NRMAWKFakeNavigationResponse alloc] initWith:url];
    
    [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationResponse:testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

- (void) testDecidePolicyForNavigationActionWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
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

- (void) testDecidePolicyForNavigationActionWithOldDelegateFunction {
    self.oldDelegateFunction = [[NRMAWKNavigationDelegateWithOldDelegateFunction alloc] init];
    self.navBaseWithDelegateFunction = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:_oldDelegateFunction];
    self.webViewWithDelegateFunction = [[WKWebView alloc] init];
    self.webViewWithDelegateFunction.navigationDelegate = _navBaseWithDelegateFunction;
    
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeNavigationAction *testAction = [[NRMAWKFakeNavigationAction alloc] initWith:url];
    
    if (@available(iOS 13.0, *)) {
        [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationAction:testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
            [testAction decisionHandler:policy];
        }];
        XCTAssertEqual(testAction.receivedPolicy, WKNavigationResponsePolicyCancel);
    }
}

- (void) testDidReceiveAuthenticationChallengeWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeURLAuthenticationChallenge *testChallenge = [[NRMAWKFakeURLAuthenticationChallenge alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction didReceiveAuthenticationChallenge:[[NSURLAuthenticationChallenge alloc] init] completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential){
        [testChallenge completionHandler:disposition withCredential:credential];
    }];
    
    XCTAssertNil(testChallenge.credential);
    XCTAssertEqual(testChallenge.authenticationChallengeDisposition, NSURLSessionAuthChallengePerformDefaultHandling);
}

- (void) testDecidePolicyForNavigationResponseWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeNavigationResponse *testResponse = [[NRMAWKFakeNavigationResponse alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationResponse:testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

- (void)testWebViewLoadTimeMetric {
    [self startWebKitLoad];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction didFinishNavigation:self.navigationItem];
    sleep(1);
    
    NSString* fullMetricName = self.url.absoluteString;
    
    NRMAHTTPTransactionMeasurement* foundMeasurement;
    
    for (id measurement in self.helper.consumedMeasurements) {
        if([((NRMAHTTPTransactionMeasurement*)measurement).url isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }
    
    XCTAssertEqualObjects(foundMeasurement.url, fullMetricName, @"Metric is not generated properly.");
}

- (void)testWebViewLoadFailedProvisionalNavigationMetric {
    [self startWebKitLoad];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webView didFailProvisionalNavigation:self.navigationItem withError:[self createNSError]];
    sleep(1);
    
    NSString* fullMetricName = self.url.absoluteString;
    
    NRMAHTTPTransactionMeasurement* foundMeasurement;
    
    for (id measurement in self.helper.consumedMeasurements) {
        if([((NRMAHTTPTransactionMeasurement*)measurement).url isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }
    
    XCTAssertEqualObjects(foundMeasurement.url, fullMetricName, @"Metric is not generated properly.");
    
}

- (void)testWebViewLoadDidFailNavigationMetric {
    [self startWebKitLoad];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webView didFailNavigation:self.navigationItem withError:[self createNSError]];
    sleep(1);
    
    NSString* fullMetricName = self.url.absoluteString;
    
    NRMAHTTPTransactionMeasurement* foundMeasurement;
    
    for (id measurement in self.helper.consumedMeasurements) {
        if([((NRMAHTTPTransactionMeasurement*)measurement).url isEqualToString:fullMetricName]) {
            foundMeasurement = measurement;
            break;
        }
    }
    
    XCTAssertEqualObjects(foundMeasurement.url, fullMetricName, @"Metric is not generated properly.");
    
}

- (void) startWebKitLoad {
    NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL:self.url];
    [self.webViewWithDelegateFunction loadRequest:urlRequest];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction didStartProvisionalNavigation:self.navigationItem];
}

- (NSError*) createNSError {
    return [NSError errorWithDomain:@"some_domain" code:100 userInfo:@{
                                                        NSLocalizedDescriptionKey:@"Something went wrong"
                                                        }];;
}
@end

@implementation NRMAWKNavigationDelegateWithDelegateFunctions
#pragma mark Delegate Functions

- (void) webView:(WKWebView*)webView didStartProvisionalNavigation:(WKNavigation*)navigation {}
- (void) webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {}
- (void) webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error {}
- (void) webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error {}

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

@implementation NRMAWKNavigationDelegateWithOldDelegateFunction
#pragma mark Delegate Functions

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationResponsePolicyCancel);
}

@end
