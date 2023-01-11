//
//  NRMAHarvestableVitals.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/14/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATraceSegment.h"

@interface NRMAHarvestableVitals : NRMATraceSegment
- (id) initWithCPUVitals:(NSDictionary*)cpu
            memoryVitals:(NSDictionary*)memory;

@property(copy,nonatomic) NSDictionary* cpuVitals;
@property(copy,nonatomic) NSDictionary* memoryVitals;
@end
