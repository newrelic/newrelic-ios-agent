//
//  NRMAMobileEvent.h
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAnalyticEventProtocol.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN
 
@interface NRMAMobileEvent : NSObject <NRMAAnalyticEventProtocol, NSSecureCoding>

@property  NSTimeInterval timestamp;
@property  NSTimeInterval sessionElapsedTimeSeconds;
@property (nonatomic, strong) NSString *eventType;
@property (strong) NSMutableDictionary<NSString *, id> *attributes;

@property (weak) id <AttributeValidatorProtocol> attributeValidator;

- (instancetype) initWithTimestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator;

- (NSTimeInterval)getEventAge;
- (BOOL)addAttribute:(NSString *)name value:(id)value;
- (BOOL)insertAttribute:(NSString *)name value:(id)value;


@end

NS_ASSUME_NONNULL_END
