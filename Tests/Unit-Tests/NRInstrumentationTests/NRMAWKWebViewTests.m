//
//  NRMAWKWebViewTests.m
//  NRInstrumentationTests
//
//  Created by Bryce Buchanan on 7/8/19.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RootTests.h"
#import "NRMAWKWebViewInstrumentation.h"
#import "NRMAWKWebViewNavigationDelegate.h"
#import <WebKit/WebKit.h>
#import <OCMock/OCMock.h>

extern id (*NRMA__WKWebView_navigationDelegate)(id self,
                                         SEL _cmd);
@interface NRMAWKWebViewTests : XCTestCase
@end


@interface Delegate : NSObject<WKNavigationDelegate>
@end

@implementation Delegate
- (void) webView:(WKWebView*)webView didStartProvisionalNavigation:(WKNavigation*)navigation {
    NSLog(@"HELP");
}
@end

@implementation NRMAWKWebViewTests
- (void)setUp {
    [NRMAWKWebViewInstrumentation instrument];
   
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NRMAWKWebViewInstrumentation deinstrument];
}

- (void)testReleaseOfInstrumentedWebViewDelegateObject {
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];

    //get the true navigation delegate (NRMAWebViewNavigationDelegate), rather than our redirected instrumented one
   id navDelegate = NRMA__WKWebView_navigationDelegate(webView,@selector(navigationDelegate));
    
    XCTAssertEqual(2, [navDelegate retainCount]);
    
    webView.navigationDelegate = nil;

    XCTAssertEqual(1, [navDelegate retainCount]); // we see the nav delegate's retain count is decreased by 1 after it is no longer used internally.
    
}


@end
