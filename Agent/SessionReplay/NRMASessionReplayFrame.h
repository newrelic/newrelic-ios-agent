//
//  NRMASessionReplayFrame.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/20/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAUIViewDetails.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrame : NSObject

@property (readonly, atomic) NSDate* timestamp;
@property (readonly, atomic) NSArray<NRMAUIViewDetails *>* nodes;

- (instancetype)initWithTimestamp:(NSDate *)date andNodes:(NSArray<NRMAUIViewDetails *>*)nodes;

@end

NS_ASSUME_NONNULL_END
