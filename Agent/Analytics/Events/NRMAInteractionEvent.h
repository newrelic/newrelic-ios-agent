//
//  NRMAInteractionEvent.h
//  Agent
//
//  Created by Mike Bruin on 8/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAMobileEvent.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAInteractionEvent : NRMAMobileEvent
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSString *name;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                      name:(NSString *) name
                                  category:(NSString *) category
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
