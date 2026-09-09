//
//  NRMAViewEvent.h
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAMobileEvent.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * The built-in event behind view-lifecycle (MobileView) and view-timing
 * (MobileViewTiming) data.
 *
 * The event type is an initializer parameter rather than being hard-coded: one class
 * serves both event types, which differ only in that name.
 *
 * `category` is injected in -JSONObject rather than added as an attribute, because
 * "category" is in +[NRMAAnalytics reservedKeywords] and NRMAAttributeValidator would
 * reject it. Same approach as NRMAUserActionEvent.
 */
@interface NRMAViewEvent : NRMAMobileEvent

@property (nonatomic, strong) NSString *category;

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                  category:(NSString *)category
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
