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

// Reports only a page-owned agent. Session replay injects its own observation-mode agent, which would
// otherwise read as a detection. Two discriminators, because the sentinel alone is not enough: a page
// whose own snippet is async may run after ours was injected and overwrite NREUM.info with its real
// license key, and a license key that is not our sentinel is positive proof of a page-owned agent.
static NSString *const kNRMABrowserAgentDetectionScript =
    @"(function(){"
    @"if(typeof window.newrelic==='undefined'){return false;}"
    @"if(!window.__nrWvInjected){return true;}"
    @"return !!(window.NREUM&&window.NREUM.info&&window.NREUM.info.licenseKey!=='NRWV_OBSERVATION_MODE');"
    @"})()";

@implementation NRMAWebViewSupportability

+ (void)recordPageFinished {
    static dispatch_once_t token;
    [self recordWebViewSupportMetric:kNRSupportabilityPrefix@"/WebView/LoadUrl" withToken:&token];
}

+ (void)startBrowserAgentDetection:(WKWebView *)webView {
    [self pollForBrowserAgent:webView attempts:0];
}

+ (void)pollForBrowserAgent:(WKWebView *)webView attempts:(NSInteger)attempts {
    if (webView == nil || attempts >= kNRMABrowserAgentMaxAttempts) {
        return;
    }

    __weak WKWebView *weakWebView = webView;
    [webView evaluateJavaScript:kNRMABrowserAgentDetectionScript
              completionHandler:^(id result, NSError *error) {
        if (error != nil || weakWebView == nil) {
            return;
        }
        if ([result boolValue]) {
            [NRMAMeasurements recordAndScopeMetricNamed:kNRMAWebViewBrowserAgentDetectedMetric value:@1];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNRMABrowserAgentPollInterval * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pollForBrowserAgent:weakWebView attempts:attempts + 1];
            });
        }
    }];
}

+ (void)recordWebViewSupportMetric:(NSString *)name withToken:(dispatch_once_t *)token {
    dispatch_once(token, ^{
        [NRMAMeasurements recordAndScopeMetricNamed:name value:@1];
    });
}

@end
