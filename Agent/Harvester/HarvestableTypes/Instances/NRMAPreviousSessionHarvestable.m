//
//  NRMAPreviousSessionHarvestable.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAPreviousSessionHarvestable.h"

@implementation NRMAPreviousSessionHarvestable {
    NRMADataToken* _dataToken;
    NRMADeviceInformation* _deviceInformation;
    NSDictionary* _attributes;
    NSArray* _events;
}

- (instancetype) initWithDataToken:(NRMADataToken*)dataToken
                 deviceInformation:(NRMADeviceInformation*)deviceInformation
                        attributes:(NSDictionary*)attributes
                            events:(NSArray*)events {
    self = [super init];
    if (self) {
        _dataToken = dataToken;
        _deviceInformation = deviceInformation;
        _attributes = attributes ?: @{};
        _events = events ?: @[];
    }
    return self;
}

// Mirrors -[NRMAHarvestData JSONObject]. The metric, transaction, trace and
// agent-health nodes are intentionally empty: this post carries only the
// previous session's analytics.
- (id) JSONObject {
    NSMutableArray* jsonArray = [[NSMutableArray alloc] init];
    [jsonArray addObject:[_dataToken JSONObject]];
    [jsonArray addObject:[_deviceInformation JSONObject]];
    [jsonArray addObject:@0];   // harvestTimeDelta
    [jsonArray addObject:@[]];  // httpTransactions
    [jsonArray addObject:@[]];  // metrics
    // EMPTY NODE is Required by spec! (Historically this was the HTTPErrors.)
    [jsonArray addObject:@[]];
    [jsonArray addObject:@[]];  // activityTraces
    // Agent health node.
    [jsonArray addObject:@[]];
    [jsonArray addObject:_attributes];  // analyticsAttributes (previous session)
    [jsonArray addObject:_events];      // analyticsEvents (previous session)
    return jsonArray;
}

@end
