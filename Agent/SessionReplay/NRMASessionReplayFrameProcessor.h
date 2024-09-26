//
//  NRMASessionReplayFrameProcessor.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMASessionReplayFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrameProcessor : NSObject

-(NSDictionary *)process:(NRMASessionReplayFrame *)frame;

@end

NS_ASSUME_NONNULL_END
