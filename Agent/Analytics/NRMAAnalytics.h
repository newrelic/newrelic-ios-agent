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
#import "NRMAUserActionBuilder.h"
#import "NRMANetworkRequestData.h"
#import "NRMANetworkResponseData.h"
#import "NRMAPayload.h"

@interface NRMAAnalytics : NSObject <NRMAHarvestAware>
- (void) setMaxEventBufferTime:(unsigned int) seconds;

- (void) setMaxEventBufferSize:(unsigned int) size;

- (id) initWithSessionStartTimeMS:(long long) sessionStartTime;

- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes;

- (BOOL) addCustomEvent:(NSString*)eventType
         withAttributes:(NSDictionary*)attributes;
- (BOOL) addNetworkRequestEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload *)payload;
- (BOOL) addHTTPErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload *)payload;
- (BOOL) addNetworkErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload*)payload;

- (NSString*) analyticsJSONString;
- (void) sessionWillEnd;
//value is either a NSString or NSNumber;
- (BOOL) setSessionAttribute:(NSString*)name value:(id)value;
- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number;
- (BOOL) setUserId:(NSString*)userId;
- (BOOL) removeSessionAttributeNamed:(NSString*)name;
- (BOOL) removeAllSessionAttributes;
- (BOOL) addBreadcrumb:(NSString*)named
        withAttributes:(NSDictionary*)attributes;

- (BOOL) addInteractionEvent:(NSString*)name interactionDuration:(double)duration_secs;
- (BOOL) recordUserAction:(NRMAUserAction *)userAction;



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
