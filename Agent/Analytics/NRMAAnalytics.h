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
- (NSUInteger) getMaxEventBufferSize;
- (void) setMaxEventBufferSize:(unsigned int) size;
- (NSUInteger) getMaxEventBufferTime;

- (id) initWithSessionStartTimeMS:(long long) sessionStartTime;

- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes;

- (BOOL) addCustomEvent:(NSString*)eventType
         withAttributes:(NSDictionary*)attributes;
- (BOOL) addNetworkRequestEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload *)payload;
- (BOOL) addHTTPErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload *)payload;
- (BOOL) addNetworkErrorEvent:(NRMANetworkRequestData *)requestData withResponse:(NRMANetworkResponseData *)responseData withNRMAPayload:(NRMAPayload*)payload;

- (NSString*) analyticsJSONString;
- (NSString*) sessionAttributeJSONString;

- (void) sessionWillEnd;
- (void) newSession;
- (void) newSessionWithStartTime:(long long) sessionStartTime;

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
- (BOOL) recordUserAction:(NRMAUserAction *)userAction;



+ (void) clearDuplicationStores;
+ (NSString*) getLastSessionsAttributes;
+ (NSString*) getLastSessionsEvents;
- (void) clearLastSessionsAnalytics;

- (BOOL) checkOfflineStatus;
- (BOOL) checkBackgroundStatus;
//this utilizes setSessionAttribute:value: which validates the user input 'name'.
- (BOOL) setLastInteraction:(NSString*)name;

//private NR attribute settings
- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value;

- (BOOL) addSessionEndAttribute;
- (BOOL) addSessionEvent;

- (id<AttributeValidatorProtocol>) getAttributeValidator;

+ (int64_t) currentTimeMillis;
+ (NSArray<NSString*>*) reservedKeywords;

@end
