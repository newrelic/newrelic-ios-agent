//
//  NRMASummaryMeasurementConsumer.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/31/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurementConsumer.h"
#import "NRMAHarvestAware.h"
#import "NRMAMetricSet.h"
@interface NRMASummaryMeasurementConsumer : NRMAMeasurementConsumer <NRMAHarvestAware>
{
}

- (void) aggregateAndNormalizeAndRecordValuesWithTotalTime:(double)totalTimeMillis
                                                     scope:(NSString*)scope;
@end
