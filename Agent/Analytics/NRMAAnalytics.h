//
//  NRMAAnalytics.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/5/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestAware.h"
#import "NRTimer.h"
#import "NRMANetworkRequestData.h"
#import "NRMANetworkResponseData.h"
#import "NRMAPayload.h"

//#define USE_INTEGRATED_EVENT_MANAGER 1
@interface NRMAAnalytics : NSObject <NRMAHarvestAware>
- (void) setMaxEventBufferTime:(unsigned int) seconds;

- (void) setMaxEventBufferSize:(unsigned int) size;

- (id) initWithSessionStartTimeMS:(long long) sessionStartTime;

- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes;

- (BOOL) addCustomEvent:(NSString*)eventType
         withAttributes:(NSDictionary*)attributes;
#if USE_INTEGRATED_EVENT_MANAGER
- (BOOL) addNetworkRequestEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withPayload:(NRMAPayload *)payload;
- (BOOL) addHTTPErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withPayload:(NRMAPayload *)payload;
- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withPayload:(NRMAPayload*)payload;
#endif

- (NSString*) analyticsJSONString;
- (void) sessionWillEnd;
//value is either a NSString or NSNumber;
- (BOOL) setSessionAttribute:(NSString*)name value:(id)value;
- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent;
- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number;
- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent;
- (BOOL) setUserId:(NSString*)userId;
- (BOOL) removeSessionAttributeNamed:(NSString*)name;
- (BOOL) removeAllSessionAttributes;
- (BOOL) addBreadcrumb:(NSString*)named
        withAttributes:(NSDictionary*)attributes;

- (BOOL) addInteractionEvent:(NSString*)name interactionDuration:(double)duration_secs;



+ (void) clearDuplicationStores;
+ (NSString*) getLastSessionsAttributes;
+ (NSString*) getLastSessionsEvents;
- (void) clearLastSessionsAnalytics;


//this utilizes setSessionAttribute:value: which validates the user input 'name'.
- (BOOL) setLastInteraction:(NSString*)name;

//private NR attribute settings
- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value;


+ (NSArray<NSString*>*) reservedKeywords;

@end
