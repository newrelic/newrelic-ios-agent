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

// NS_SWIFT_NAME is required: this method's name matches the class name, so Swift's importer would
// otherwise treat it as a factory and map it to init(), returning a new instance, not the singleton.
+ (NRMAHarvestController* _Nullable) harvestController NS_SWIFT_NAME(shared());

+ (void) setPeriod:(long long)period;

+ (void) initialize:(NRMAAgentConfiguration* _Nonnull)configuration;

+ (void) start;

+ (void) stop;

- (void) createHarvester;

- (NRMAHarvester* _Nullable) harvester;

- (NRMAHarvestTimer* _Nullable) harvestTimer;

- (void) deinitialize;

/// Whether the harvest buffer has room for another activity trace: `retained < at_capture max`.
/// The buffer is cleared on a successful harvest, so a failing or rate-limited harvest keeps it full.
+ (BOOL) shouldCollectTraces;

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

// Stages already-resolved recovered events as plain JSON dictionaries. Unlike
// +addHarvestableAnalytics:, never touches harvestData.analyticsAttributes, so a
// recovered session's attributes can't clobber the current session's.
+ (void) addRecoveredAnalyticsEvents:(NSArray* _Nonnull)events;

// Uploads recovered events in their own request, with data_token's realAgentId set to
// the value they were actually recorded under (clusterAgentId stays this session's --
// it's invariant across app versions). Ingest resolves appVersion only from data_token,
// not from any header or JSON attribute, so this is the only way to re-attribute a
// recovered event correctly. Must only run after this session's own connect/harvest has
// succeeded (see NR-646833 -- uploading earlier gets rejected outright). `eventUUIDs`
// are confirmed (deleted) only once this upload succeeds.
+ (void) uploadRecoveredAnalyticsEvents:(NSArray* _Nonnull)events
                              eventUUIDs:(NSArray* _Nonnull)eventUUIDs
                             realAgentId:(long long)realAgentId;
@end

#ifdef __cplusplus
}
#endif
