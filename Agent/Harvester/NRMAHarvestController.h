//
//  NRMAHarvest.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/3/13.
//  Copyright © 2023 New Relic. All rights reserved.
//
#ifdef __cplusplus
 extern "C" {
#endif

#import <Foundation/Foundation.h>
#import "NRMAHarvester.h"
#import "NRMAHarvestTimer.h"
#import "NRMAHarvestableMetric.h"
#import "NRMAHarvestableActivity.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAHarvestableAnalytics.h"


@interface NRMAHarvestController : NSObject

+ (NRMAHarvestController* _Nullable) harvestController;

+ (void) setPeriod:(long long)period;

+ (void) initialize:(NRMAAgentConfiguration* _Nonnull)configuration;

+ (void) start;

+ (void) stop;

- (void) createHarvester;

- (NRMAHarvester* _Nullable) harvester;

- (NRMAHarvestTimer* _Nullable) harvestTimer;

- (void) deinitialize;

+ (BOOL) shouldNotCollectTraces;

+ (void) setMaxOfflineStorageSize:(NSUInteger) size;

#pragma mark - HarvestController interface

+ (NRMAHarvesterConfiguration*_Nullable) configuration;

+ (NRMAHarvestData* _Nullable) harvestData;

+ (void) addHarvestListener:(id<NRMAHarvestAware> _Nonnull)obj;

+ (void) removeHarvestListener:(id<NRMAHarvestAware> _Nonnull)obj;

#pragma mark - for testing

+ (BOOL) harvestNow;


#pragma mark - for crash handling

+ (void) recovery;


#pragma mark - harvest data interface

+ (void) addHarvestableHTTPTransaction:(NRMAHarvestableHTTPTransaction* _Nonnull)transaction;

+ (void) addNamedValue:(NRMANamedValueMeasurement* _Nonnull)measurement;

+ (void) addHarvestableActivity:(NRMAHarvestableActivity* _Nonnull)activity;

+ (void) addHarvestableAnalytics:(NRMAHarvestableAnalytics* _Nonnull)analytics;
@end

#ifdef __cplusplus
}
#endif
