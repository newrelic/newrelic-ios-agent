//
//  NRMAAppInstallMetricGenerator.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/19/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestAware.h"

@interface NRMAAppInstallMetricGenerator : NSObject <NRMAHarvestAware>
- (instancetype) init;
@end
