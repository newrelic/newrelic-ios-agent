//
//  NRMAHarvestLifecycleAware.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/30/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NRMAHarvestAware <NSObject>
@optional
- (void) onHarvestStart;
- (void) onHarvestStop;
- (void) onHarvestBefore;
- (void) onHarvest;
- (void) onHarvestError;
- (void) onHarvestComplete;
@end
