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
 
@interface NRMAMobileEvent : NSObject <NRMAJSONABLE>

@property  NSTimeInterval timestamp;
@property  unsigned long long sessionElapsedTimeSeconds;
@property (nonatomic) NSString *eventType;
@property (nonatomic) NSMutableDictionary<NSString *, id> *attributes;

@property (weak) id <AttributeValidatorProtocol> attributeValidator;

- (instancetype) initWithEventType:(NSString *)eventType
                         timestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
            withAttributeValidator:(id<AttributeValidatorProtocol>) attributeValidator;

- (NSTimeInterval)getEventAge;
- (BOOL)addAttribute:(NSString *)name value:(id)value;


@end

NS_ASSUME_NONNULL_END
