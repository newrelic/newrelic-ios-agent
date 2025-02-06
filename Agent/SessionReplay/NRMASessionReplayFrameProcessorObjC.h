//
//  NRMASessionReplayFrameProcessor.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMASessionReplayFrameObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrameProcessorObjC : NSObject

-(NSDictionary *)process:(NRMASessionReplayFrameObjC *)frame;

@end

NS_ASSUME_NONNULL_END
