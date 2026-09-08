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
#import "NRMAWebViewSupportability.h"
#import "NRMANamedValueMeasurement.h"
#import "NRConstants.h"

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@interface NRMAWKNavigationDelegateWithDelegateFunctions : NSObject <WKNavigationDelegate>
@end

@interface NRMAWKNavigationDelegateWithOldDelegateFunction : NSObject <WKNavigationDelegate>
@end

// Implements the optional webViewWebContentProcessDidTerminate: callback. Used to
// reproduce the crash that occurs when WebKit caches respondsToSelector: == YES while
// this delegate is alive, the delegate is then deallocated (the proxy holds it weakly),
// and WebKit later fires the cached callback against the orphaned proxy.
@interface NRMAWKNavigationDelegateWithTerminateFunction : NSObject <WKNavigationDelegate>
@property(nonatomic) BOOL didTerminateCalled;
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
@property(strong) NRMAWKWebViewNavigationDelegate* navBaseWithOldDelegateFunction;
@property(strong) NRMAWKNavigationDelegateWithOldDelegateFunction* oldDelegateFunction;
@property(strong) WKWebView* webViewWithOldDelegateFunction;
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
    
    self.oldDelegateFunction = [[NRMAWKNavigationDelegateWithOldDelegateFunction alloc] init];
    self.navBaseWithOldDelegateFunction = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:_oldDelegateFunction];
    self.webViewWithOldDelegateFunction = [[WKWebView alloc] init];
    self.webViewWithOldDelegateFunction.navigationDelegate = _navBaseWithOldDelegateFunction;
    
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
    
    [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationAction:(WKNavigationAction *)testAction decisionHandler:^(WKNavigationActionPolicy policy){
        [testAction decisionHandler:policy];
    }];
    
    XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    
    if (@available(iOS 13.0, *)) {
        [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationAction:(WKNavigationAction *)testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
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
    
    [self.webView.navigationDelegate webView:self.webView decidePolicyForNavigationResponse:(WKNavigationResponse *)testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

- (void) testDecidePolicyForNavigationActionWithDelegateFunctions {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeNavigationAction *testAction = [[NRMAWKFakeNavigationAction alloc] initWith:url];
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationAction:(WKNavigationAction *)testAction decisionHandler:^(WKNavigationActionPolicy policy){
        [testAction decisionHandler:policy];
    }];
    
    XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    
    if (@available(iOS 13.0, *)) {
        [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationAction:(WKNavigationAction *)testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
            [testAction decisionHandler:policy];
        }];
        XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyAllow);
    }
}

- (void) testDecidePolicyForNavigationActionWithOldDelegateFunction {
    NSURLRequest* url = [[NSURLRequest alloc] initWithURL:self.url];
    
    NRMAWKFakeNavigationAction *testAction = [[NRMAWKFakeNavigationAction alloc] initWith:url];
    
    if (@available(iOS 13.0, *)) {
        [self.webViewWithOldDelegateFunction.navigationDelegate webView:self.webViewWithOldDelegateFunction decidePolicyForNavigationAction:(WKNavigationAction *)testAction preferences:[[WKWebpagePreferences alloc] init] decisionHandler:^(WKNavigationActionPolicy policy, WKWebpagePreferences* preference){
            [testAction decisionHandler:policy];
        }];
        XCTAssertEqual(testAction.receivedPolicy, WKNavigationActionPolicyCancel);
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
    
    [self.webViewWithDelegateFunction.navigationDelegate webView:self.webViewWithDelegateFunction decidePolicyForNavigationResponse:(WKNavigationResponse *)testResponse decisionHandler:^(WKNavigationResponsePolicy policy){
        [testResponse decisionHandler:policy];
    }];;
    
    XCTAssertEqual(testResponse.receivedPolicy, WKNavigationResponsePolicyAllow);
}

// Reproduces NR-414430 / the 7.7.0 crash:
// "-[NRMAWKWebViewNavigationDelegate webViewWebContentProcessDidTerminate:]: unrecognized selector".
// WebKit caches respondsToSelector: == YES while the real delegate is alive, the real
// delegate is later deallocated (the proxy holds it weakly), and WebKit fires the cached
// callback against the orphaned proxy. The proxy must absorb the message, not crash.
- (void) testWebContentProcessDidTerminateAfterRealDelegateDeallocated {
    NRMAWKWebViewNavigationDelegate* proxy;
    @autoreleasepool {
        NRMAWKNavigationDelegateWithTerminateFunction* realDelegate = [[NRMAWKNavigationDelegateWithTerminateFunction alloc] init];
        proxy = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:realDelegate];
        // WebKit caches this == YES at delegate-assignment time, while realDelegate is alive.
        XCTAssertTrue([proxy respondsToSelector:@selector(webViewWebContentProcessDidTerminate:)]);
        realDelegate = nil;
    }

    // The weak realDelegate has now been zeroed by the deallocation above.
    XCTAssertNil(proxy.realDelegate);

    // WebKit fires the cached callback. With the bug this throws an unrecognized-selector
    // NSInvalidArgumentException via the message-forwarding fall-through.
    id<WKNavigationDelegate> nav = (id<WKNavigationDelegate>)proxy;
    XCTAssertNoThrow([nav webViewWebContentProcessDidTerminate:self.webView]);
}

// Guards the happy path: while the real delegate is alive, an optional callback that only
// the real delegate implements must still be forwarded to it.
- (void) testWebContentProcessDidTerminateForwardsToLiveDelegate {
    NRMAWKNavigationDelegateWithTerminateFunction* realDelegate = [[NRMAWKNavigationDelegateWithTerminateFunction alloc] init];
    NRMAWKWebViewNavigationDelegate* proxy = [[NRMAWKWebViewNavigationDelegate alloc] initWithOriginalDelegate:realDelegate];

    id<WKNavigationDelegate> nav = (id<WKNavigationDelegate>)proxy;
    XCTAssertNoThrow([nav webViewWebContentProcessDidTerminate:self.webView]);
    XCTAssertTrue(realDelegate.didTerminateCalled);
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
    decisionHandler(WKNavigationActionPolicyCancel);
}

@end

@implementation NRMAWKNavigationDelegateWithTerminateFunction
#pragma mark Delegate Functions

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    self.didTerminateCalled = YES;
}

@end

// ---------------------------------------------------------------------------
#pragma mark - NRMAWebViewBrowserAgentDetectionTests

@interface NRMAWebViewBrowserAgentDetectionTests : XCTestCase
@property (strong) NRMAMeasurementConsumerHelper *helper;
@end

@implementation NRMAWebViewBrowserAgentDetectionTests

- (void)setUp {
    [super setUp];
    [NRMATaskQueue clear];
    self.helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:self.helper];
}

- (void)tearDown {
    [NRMAMeasurements removeMeasurementConsumer:self.helper];
    self.helper = nil;
    [NRMAMeasurements shutdown];
    [super tearDown];
}

- (void)testDetectionRecordsMetricWhenBrowserAgentPresent {
    WKWebView *webView = [[WKWebView alloc] init];
    [webView loadHTMLString:@"<script>window.newrelic = {}</script>" baseURL:nil];

    NSDate *loadDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while (webView.isLoading && [NSDate.date compare:loadDeadline] == NSOrderedAscending) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    XCTAssertFalse(webView.isLoading, @"WebView timed out while loading");

    [NRMAWebViewSupportability startBrowserAgentDetection:webView];

    // Poll until the specific browser agent metric arrives (ignore other NRMANamedValueMeasurements
    // such as memory/CPU produced by NRMANamedValueProducer while the run loop spins).
    NSDate *detectDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    NRMANamedValueMeasurement *found = nil;
    while (!found && [NSDate.date compare:detectDeadline] == NSOrderedAscending) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [NRMATaskQueue synchronousDequeue];
        for (NRMANamedValueMeasurement *m in self.helper.consumedMeasurements) {
            if ([m.name isEqualToString:kNRMAWebViewBrowserAgentDetectedMetric]) {
                found = m;
                break;
            }
        }
    }

    XCTAssertNotNil(found, @"Browser agent detection metric should be recorded");
    XCTAssertEqualObjects(found.name, kNRMAWebViewBrowserAgentDetectedMetric);
}

- (void)testDetectionDoesNotRecordMetricWhenBrowserAgentAbsent {
    // Use an unloaded WKWebView — it has no JavaScript context that could define
    // window.newrelic, eliminating the unreliable page-load wait and any chance of
    // picking up injected scripts.  evaluateJavaScript: on an unloaded WebView either
    // errors immediately (our handler returns early) or evaluates to false; neither
    // path records the metric.
    WKWebView *webView = [[WKWebView alloc] init];

    [NRMAWebViewSupportability startBrowserAgentDetection:webView];

    // Spin long enough for all 8 polling attempts to exhaust (8 × 250 ms = 2 s).
    NSDate *pollDeadline = [NSDate dateWithTimeIntervalSinceNow:2.5];
    while ([NSDate.date compare:pollDeadline] == NSOrderedAscending) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [NRMATaskQueue synchronousDequeue];
    }

    BOOL browserAgentMetricRecorded = NO;
    for (NRMANamedValueMeasurement *m in self.helper.consumedMeasurements) {
        if ([m.name isEqualToString:kNRMAWebViewBrowserAgentDetectedMetric]) {
            browserAgentMetricRecorded = YES;
            break;
        }
    }
    XCTAssertFalse(browserAgentMetricRecorded, @"Browser agent detection metric should not be recorded when browser agent is absent");
}

- (void)testDetectionDoesNotRetainWebView {
    __weak WKWebView *weakRef = nil;

    @autoreleasepool {
        WKWebView *webView = [[WKWebView alloc] init];
        weakRef = webView;
        [NRMAWebViewSupportability startBrowserAgentDetection:webView];
        // webView's only strong owner goes out of scope here
    }

    // Spin the run loop to let any in-flight dispatch_after blocks fire and release.
    // The blocks capture weakWebView weakly, so they cannot keep the WKWebView alive.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];

    XCTAssertNil(weakRef, @"Detection polling must not hold a strong reference to WKWebView");
}

@end
