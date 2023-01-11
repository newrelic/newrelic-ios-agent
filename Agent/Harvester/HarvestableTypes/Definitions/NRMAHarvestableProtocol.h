//
//  NRHarvestable.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/26/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum  {
    NRMA_HARVESTABLE_OBJECT,
    NRMA_HARVESTABLE_ARRAY,
    NRMA_HARVESTABLE_VALUE
} NRMAHarvestableType;

@protocol NRMAHarvestableProtocol <NSObject>
@property(readonly) NRMAHarvestableType type;
@end
