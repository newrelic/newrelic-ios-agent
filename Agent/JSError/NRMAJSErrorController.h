//
//  NRMAJSErrorController.h
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAAnalytics.h"
#import "NRMAHarvestAware.h"

@class NRMAAgentConfiguration;

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kJSErrorBackupStoreFolder;

@interface NRMAJSErrorController : NSObject <NRMAHarvestAware>

@property (strong, nullable) NSString* sessionId;
@property (strong, nullable) NSDate* sessionStartDate;

- (instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics
                            sessionStartTime:(NSDate*)sessionStartDate
                          agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
                                    platform:(NSString*)platform
                                   sessionId:(NSString*)sessionId
                          attributeValidator:(id<AttributeValidatorProtocol>) attributeValidator;

/*!
 * Record a JavaScript error for the Mobile Errors Protocol.
 *
 * @param name The type of JS error (e.g., TypeError, ReferenceError)
 * @param message The error message
 * @param stackTrace The full JS stack trace string
 * @param isFatal Boolean indicating if the error caused a crash/hang
 * @param jsAppVersion The version of the JS bundle
 * @param additionalAttributes Optional custom metadata
 */
- (void) recordJSError:(NSString*)name
               message:(NSString*)message
            stackTrace:(NSString*)stackTrace
               isFatal:(BOOL)isFatal
          jsAppVersion:(NSString* _Nullable)jsAppVersion
 additionalAttributes:(NSDictionary* _Nullable)additionalAttributes;

/*!
 * Process and publish any persisted JS errors from disk.
 * Called during harvest when network becomes available.
 */
- (void) processAndPublishPersistedErrors;

@end

NS_ASSUME_NONNULL_END
