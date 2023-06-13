//
//  NRMAEventManager.h
//  Agent
//
//  Created by Steve Malsam on 6/7/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAAnalyticEventProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAEventManager : NSObject

- (instancetype)init;
- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event;
- (nullable NSString *)getEventJSONStringWithError:( NSError * _Nullable *)error;
@end

NS_ASSUME_NONNULL_END
