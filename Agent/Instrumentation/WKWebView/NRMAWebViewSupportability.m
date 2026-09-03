//
//  NRMAWebViewSupportability.m
//  Agent
//
//  Created by Chris Dillard on 10/27/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAWebViewSupportability.h"
#import "NRMAMeasurements.h"
#import "NRConstants.h"
#import <WebKit/WebKit.h>

static const NSInteger kNRMABrowserAgentMaxAttempts = 8;
static const NSTimeInterval kNRMABrowserAgentPollInterval = 0.250;
static BOOL sNRMABrowserAgentDetected = NO;

@implementation NRMAWebViewSupportability

+ (void)recordPageFinished {
    static dispatch_once_t token;
    [self recordWebViewSupportMetric:kNRSupportabilityPrefix@"/WebView/LoadUrl" withToken:&token];
}

+ (void)startBrowserAgentDetection:(WKWebView *)webView {
    if (sNRMABrowserAgentDetected) {
        return;
    }
    [self pollForBrowserAgent:webView attempts:0];
}

+ (void)pollForBrowserAgent:(WKWebView *)webView attempts:(NSInteger)attempts {
    if (webView == nil || attempts >= kNRMABrowserAgentMaxAttempts) {
        return;
    }

    __weak WKWebView *weakWebView = webView;
    [webView evaluateJavaScript:@"typeof window.newrelic !== 'undefined'"
              completionHandler:^(id result, NSError *error) {
        if (error != nil || weakWebView == nil) {
            return;
        }
        if ([result boolValue]) {
            [self recordBrowserAgentDetected];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNRMABrowserAgentPollInterval * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pollForBrowserAgent:weakWebView attempts:attempts + 1];
            });
        }
    }];
}

+ (void)recordBrowserAgentDetected {
    sNRMABrowserAgentDetected = YES;
    static dispatch_once_t token;
    [self recordWebViewSupportMetric:kNRMAWebViewBrowserAgentDetectedMetric withToken:&token];
}

+ (void)recordWebViewSupportMetric:(NSString *)name withToken:(dispatch_once_t *)token {
    dispatch_once(token, ^{
        [NRMAMeasurements recordAndScopeMetricNamed:name value:@1];
    });
}

@end
