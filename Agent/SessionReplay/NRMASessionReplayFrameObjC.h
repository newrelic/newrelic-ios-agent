//
//  NRMASessionReplayFrame.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/20/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAUIViewDetailsObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrameObjC : NSObject

@property (readonly, atomic) NSDate* timestamp;
@property (readonly, atomic) NSArray<NRMAUIViewDetailsObjC *>* nodes;

- (instancetype)initWithTimestamp:(NSDate *)date andNodes:(NSArray<NRMAUIViewDetailsObjC *>*)nodes;

@end

NS_ASSUME_NONNULL_END
