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
 */
@interface NRMAViewEvent : NRMAMobileEvent

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
