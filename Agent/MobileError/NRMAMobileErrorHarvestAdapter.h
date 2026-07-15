//
//  NRMAMobileErrorHarvestAdapter.h
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestAware.h"

#if TARGET_OS_IOS

@class MobileErrorController;

NS_ASSUME_NONNULL_BEGIN

/// Adapter to bridge MobileErrorController (Swift) with NRMAHarvestAware protocol (iOS only - for React Native)
@interface NRMAMobileErrorHarvestAdapter : NSObject <NRMAHarvestAware>

- (instancetype)initWithController:(MobileErrorController*)controller;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS
