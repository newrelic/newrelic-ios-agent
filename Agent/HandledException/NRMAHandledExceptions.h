//
//  NRMAHandledExceptions.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/26/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAAnalytics.h"
#import "NRMAHarvestAware.h"

@class NRMAAgentConfiguration;

NS_ASSUME_NONNULL_BEGIN

extern const NSString* kHexBackupStoreFolder;

@interface NRMAHandledExceptions : NSObject <NRMAHarvestAware>
@property (strong) NSString* _Nullable sessionId;
@property(strong) NSDate* _Nullable sessionStartDate;

- (instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics
                            sessionStartTime:(NSDate*)sessionStartDate
                          agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
                                    platform:(NSString*)platform
                                   sessionId:(NSString*)sessionId
                          attributeValidator:(id<AttributeValidatorProtocol>) attributeValidator;

- (void) recordHandledException:(NSException*) exception
                     attributes:(NSDictionary* _Nullable)attributes;

- (void) recordHandledException:(NSException*) exception;

- (void) recordError:(NSError* _Nonnull)error attributes:(NSDictionary* _Nullable)attributes;

- (void) processAndPublishPersistedReports;


- (void) recordHandledExceptionWithStackTrace:(NSDictionary* _Nonnull)exceptionDictionary;
@end

NS_ASSUME_NONNULL_END
