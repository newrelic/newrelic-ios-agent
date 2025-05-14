//
//  Agent.h
//  Agent
//
//  Created by Bryce Buchanan on 7/23/20.
//  Copyright © 2023 New Relic. All rights reserved.
//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright © 2023 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

#import <Foundation/Foundation.h>

//! Project version number for Agent.
FOUNDATION_EXPORT double AgentVersionNumber;

//! Project version string for Agent.
FOUNDATION_EXPORT const unsigned char AgentVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Agent/PublicHeader.h>

#import <NewRelicAgent/NewRelic.h>
#import <NewRelicAgent/NRConstants.h>
#import <NewRelicAgent/NewRelicCustomInteractionInterface.h>
#import <NewRelicAgent/NewRelicFeatureFlags.h>
#import <NewRelicAgent/NRCustomMetrics.h>
#import <NewRelicAgent/NRLogger.h>
#import <NewRelicAgent/NRCustomMetrics.h>
#import <NewRelicAgent/NRTimer.h>
#import <NewRelicAgent/NRURLSessionTaskDelegateBase.h>
#import <NewRelicAgent/NRWKNavigationDelegateBase.h>
