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

@implementation NRMAWebViewSupportability

+ (void)recordPageFinished {
    static dispatch_once_t token;
    [self recordWebViewSupportMetric:kNRSupportabilityPrefix@"/WebView/LoadUrl" withToken:&token];
}

+ (void)recordWebViewSupportMetric:(NSString *)name withToken:(dispatch_once_t *)token {
    dispatch_once(token, ^{
        [NRMAMeasurements recordAndScopeMetricNamed:name value:@1];
    });
}

@end
