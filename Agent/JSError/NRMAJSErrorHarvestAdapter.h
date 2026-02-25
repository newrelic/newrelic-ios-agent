//
//  NRMAJSErrorHarvestAdapter.h
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestAware.h"

@class JSErrorController;

NS_ASSUME_NONNULL_BEGIN

/// Adapter to bridge JSErrorController (Swift) with NRMAHarvestAware protocol
@interface NRMAJSErrorHarvestAdapter : NSObject <NRMAHarvestAware>

- (instancetype)initWithController:(JSErrorController*)controller;

@end

NS_ASSUME_NONNULL_END
