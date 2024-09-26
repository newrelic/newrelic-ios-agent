//
//  NRMASessionReplayFrame.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/20/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAViewDetailProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrame : NSObject

@property (readonly, atomic) NSDate* timestamp;
@property (readonly, atomic) NSArray<Node>* nodes;

- (instancetype)initWithTimestamp:(NSDate *)date andNodes:(NSArray<Node>*)nodes;

@end

NS_ASSUME_NONNULL_END
