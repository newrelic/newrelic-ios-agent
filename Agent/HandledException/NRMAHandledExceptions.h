//
//  NRMAHandledExceptions.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/26/17.
//  Copyright © 2017 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAAnalytics.h"
#import "NRMAHarvestAware.h"

@class NRMAAgentConfiguration;

extern const NSString* kHexBackupStoreFolder;

@interface NRMAHandledExceptions : NSObject <NRMAHarvestAware>
@property (strong) NSString* sessionId;
@property(strong) NSDate* sessionStartDate;

- (instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics
                            sessionStartTime:(NSDate*)sessionStartDate
                          agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
                                    platform:(NSString*)platform
                                   sessionId:(NSString*)sessionId;

- (void) recordHandledException:(NSException*) exception
                     attributes:(NSDictionary*)attributes;

- (void) recordHandledException:(NSException*) exception;

- (void) recordError:(NSError* _Nonnull)error attributes:(NSDictionary* _Nullable)attributes;

- (void) processAndPublishPersistedReports;


- (void) recordHandledExceptionWithStackTrace:(NSDictionary* _Nonnull)exceptionDictionary;
@end
