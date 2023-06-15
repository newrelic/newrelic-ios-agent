//
//  NRMACustomEvent.h
//  Agent
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAAnalyticEventProtocol.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMACustomEvent : NSObject <NRMAAnalyticEventProtocol>

@property (readonly) NSTimeInterval timestamp;
@property (readonly) unsigned long long sessionElapsedTimeSeconds;
@property (nonatomic, readonly) NSString *eventType;
@property (weak, readonly) id <AttributeValidatorProtocol> attributeValidator;

- (instancetype) initWithEventType:(NSString *)eventType
                         timestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
            withAttributeValidator:(id<AttributeValidatorProtocol>) attributeValidator;


@end

NS_ASSUME_NONNULL_END
