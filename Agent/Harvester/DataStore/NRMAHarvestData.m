//
//  NRMAHarvestData.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/4/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestData.h"
#import "NRMAHarvestController.h"
@implementation NRMAHarvestData

- (id) init
{
    self = [super init];
    if (self) {
        self.dataToken = [[NRMADataToken alloc] init];

        self.deviceInformation = [NRMAAgentConfiguration connectionInformation].deviceInformation;
        
        self.httpTransactions = [[NRMAHTTPTransactions alloc] init];
        [NRMAHarvestController addHarvestListener:self.httpTransactions];

        self.metrics = [[NRMAMetricSet alloc] init];
        [NRMAHarvestController addHarvestListener:self.metrics];
        
        self.activityTraces   = [[NRMAActivityTraces alloc] init];
        [NRMAHarvestController addHarvestListener:self.activityTraces];

        self.analyticsAttributes = [NSDictionary new];

        self.analyticsEvents = [[NRMAAnalyticsEvents alloc] init];
        [NRMAHarvestController addHarvestListener:self.analyticsEvents];

    }
    return self;
}

- (id) JSONObject
{
    NSMutableArray* jsonArray = [[NSMutableArray alloc] init];
    [jsonArray addObject:[self.dataToken JSONObject]];
    [jsonArray addObject:[self.deviceInformation JSONObject]];
    [jsonArray addObject:[NSNumber numberWithLongLong:self.harvestTimeDelta]];
    [jsonArray addObject:[self.httpTransactions JSONObject]];
    [jsonArray addObject:[self.metrics JSONObject]];
    // EMPTY NODE is Required by spec! Removing the following line will cause all metrics to fail to be sent to NR.(Historically this was the HTTPErrors.
    [jsonArray addObject:@[]];
    [jsonArray addObject:[self.activityTraces JSONObject]];
    // Agent health node.
    [jsonArray addObject:@[]];
    [jsonArray addObject:self.analyticsAttributes];
    [jsonArray addObject:[self.analyticsEvents JSONObject]];
    return jsonArray;
}

- (void) clear
{
    [self.httpTransactions clear];
    [self.metrics reset];
    [self.activityTraces clear];
    self.analyticsAttributes = @{};
    [self.analyticsEvents clear];
}


- (void) addMetrics:(NRMAMetricSet*)objects
{
    [self.metrics addMetrics:objects];
}

- (void) dealloc {
    [NRMAHarvestController removeHarvestListener:self.metrics];
    [NRMAHarvestController removeHarvestListener:self.httpTransactions];
    [NRMAHarvestController removeHarvestListener:self.activityTraces];
    [NRMAHarvestController removeHarvestListener:self.analyticsEvents];
}

@end
