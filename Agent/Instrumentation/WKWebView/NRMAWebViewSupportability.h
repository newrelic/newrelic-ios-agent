//
//  NRMAWebViewSupportability.h
//  Agent
//
//  Created by Chris Dillard on 10/27/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WKWebView;

@interface NRMAWebViewSupportability : NSObject

+ (void)recordPageFinished;
+ (void)startBrowserAgentDetection:(WKWebView *)webView;

@end

