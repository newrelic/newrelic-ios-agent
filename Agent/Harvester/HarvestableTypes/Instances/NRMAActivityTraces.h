//
//  NRActivityTraces.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/13/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestableArray.h"
#import "NRMAHarvestAware.h"
#import "NRMAHarvestableActivity.h"
#define kNRStoreActivityTraceNotification  @"com.newrelic.storeActivityTrace"
@interface NRMAActivityTraces : NRMAHarvestableArray <NRMAHarvestAware>
@property(nonatomic,strong) NSMutableArray* activityTraces;
- (void) clear;
- (int) count;
- (void) addActivityTraces:(NRMAHarvestableActivity*) activity;
@end
