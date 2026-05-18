//
//  NRMAJSErrorHarvestAdapter.h
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestAware.h"

#if TARGET_OS_IOS

@class JSErrorController;

NS_ASSUME_NONNULL_BEGIN

/// Adapter to bridge JSErrorController (Swift) with NRMAHarvestAware protocol (iOS only - for React Native)
@interface NRMAJSErrorHarvestAdapter : NSObject <NRMAHarvestAware>

- (instancetype)initWithController:(JSErrorController*)controller;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS
