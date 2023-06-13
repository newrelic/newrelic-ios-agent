//
//  NRMAAnalyticEvent.h
//  Agent
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAAnalyticEventProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAAnalyticEvent : NSObject <NRMAAnalyticEventProtocol>

@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) unsigned long long sessionElapsedTimeSeconds;

- (instancetype)initWithTimestamp:(NSTimeInterval) timestamp
      sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds;

@end

NS_ASSUME_NONNULL_END
