//
//  NRMAHarvestData.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/4/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestableArray.h"
#import "NRMADeviceInformation.h"
#import "NRMAHTTPTransactions.h"
#import "NRMADataToken.h"
#import "NRMAMetricSet.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAActivityTraces.h"
#import "NRMAAnalytics.h"
#import "NRMAAnalyticsEvents.h"

@interface NRMAHarvestData : NRMAHarvestableArray
@property(atomic,strong) NRMADataToken* dataToken;
@property(atomic,strong) NRMADeviceInformation* deviceInformation;
@property(atomic,assign) long long harvestTimeDelta;
@property(atomic,strong) NRMAHTTPTransactions* httpTransactions;
@property(atomic,strong) NRMAMetricSet* metrics;
@property(atomic,strong) NRMAActivityTraces* activityTraces;
@property(atomic,strong) NSDictionary* analyticsAttributes;
@property(atomic,strong) NRMAAnalyticsEvents* analyticsEvents;

- (id) init;
- (id)JSONObject;
- (void) clear;
@end
