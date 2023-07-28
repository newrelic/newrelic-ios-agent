//
//  NRMARequestEvent.h
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMACustomEvent.h"
#import "NRMAAnalyticEventProtocol.h"
#import "AttributeValidatorProtocol.h"
#import "NRMAPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMARequestEvent : NRMACustomEvent <NRMAAnalyticEventProtocol>
@property (weak, readonly) NRMAPayload* payload;

@end

NS_ASSUME_NONNULL_END
