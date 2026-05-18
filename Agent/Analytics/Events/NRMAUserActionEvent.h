//
//  NRMAUserActionEvent.h
//  Agent
//
//  Created by Mike Bruin on 1/29/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAMobileEvent.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAUserActionEvent : NRMAMobileEvent
@property (nonatomic, strong) NSString *category;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                  category:(NSString *) category
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
