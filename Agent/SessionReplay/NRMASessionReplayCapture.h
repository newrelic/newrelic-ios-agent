//
//  NRMASessionReplayCapture.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "NRMAViewDetailProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayCapture : NSObject

-(NSArray<id<NRMAViewDetailProtocol>>*)recordFromRootView:(UIView *)rootView;

@end

NS_ASSUME_NONNULL_END
