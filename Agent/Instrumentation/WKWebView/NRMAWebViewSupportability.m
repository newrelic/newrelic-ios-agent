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
// Incremented by resetPollCycleForTesting to invalidate in-flight retries from previous cycles.
static NSUInteger sNRMABrowserAgentPollCycle = 0;

@implementation NRMAWebViewSupportability

+ (void)recordPageFinished {
    static dispatch_once_t token;
    [self recordWebViewSupportMetric:kNRSupportabilityPrefix@"/WebView/LoadUrl" withToken:&token];
}

+ (void)startBrowserAgentDetection:(WKWebView *)webView {
    [self pollForBrowserAgent:webView attempts:0 cycle:sNRMABrowserAgentPollCycle];
}

+ (void)pollForBrowserAgent:(WKWebView *)webView attempts:(NSInteger)attempts cycle:(NSUInteger)cycle {
    if (webView == nil || attempts >= kNRMABrowserAgentMaxAttempts) {
        return;
    }

    __weak WKWebView *weakWebView = webView;
    [webView evaluateJavaScript:@"typeof window.newrelic !== 'undefined'"
              completionHandler:^(id result, NSError *error) {
        if (error != nil || weakWebView == nil || cycle != sNRMABrowserAgentPollCycle) {
            return;
        }
        if ([result boolValue]) {
            [NRMAMeasurements recordAndScopeMetricNamed:kNRMAWebViewBrowserAgentDetectedMetric value:@1];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNRMABrowserAgentPollInterval * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pollForBrowserAgent:weakWebView attempts:attempts + 1 cycle:cycle];
            });
        }
    }];
}

#ifdef DEBUG
+ (void)resetPollCycleForTesting {
    sNRMABrowserAgentPollCycle++;
}
#endif

+ (void)recordWebViewSupportMetric:(NSString *)name withToken:(dispatch_once_t *)token {
    dispatch_once(token, ^{
        [NRMAMeasurements recordAndScopeMetricNamed:name value:@1];
    });
}

@end
