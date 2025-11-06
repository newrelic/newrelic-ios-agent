//
//  NRMAWebViewSupportability.m
//  Agent
//
//  Created by Chris Dillard on 10/27/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAMeasurements.h"
#import "NRConstants.h"

void NRMAWebViewSupportabilityRecordPageFinished(void) {
    static dispatch_once_t token;
    NRMARecordWebViewSupportMetric(kNRSupportabilityPrefix@"/WKWebView/PageFinished", &token);
}

static void NRMARecordWebViewSupportMetric(NSString *name, dispatch_once_t *token) {
    dispatch_once(token, ^{
        [NRMAMeasurements recordAndScopeMetricNamed:name value:@1];
    });
}
