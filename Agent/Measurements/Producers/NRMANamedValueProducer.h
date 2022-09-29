//
//  NRMAMemoryMeasurementsProducer.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/30/13.
//  Copyright (c) 2013 New Relic. All rights reserved.
//

#import "NRMAMeasurementProducer.h"
#import "NRMAHarvestAware.h"
#import "NRMACPUVitals.h"
#define NRMA_METRIC_MEMORY_USAGE          @"Memory/Used"
#define NRMA_METRIC_USER_CPU_TIME         @"CPU/User/Utilization"
#define NRMA_METRIC_SYSTEM_CPU_TIME       @"CPU/System/Utilization"
#define NRMA_METRIC_TOTAL_CPU_TIME        @"CPU/Total/Utilization"
#define NRMA_METRIC_SESSION_DURATION      @"Session/Duration"

#define NRMA_METRIC_APP_LAUNCH_COLD        @"AppLaunch/Cold"
#define NRMA_METRIC_APP_LAUNCH_RESUME      @"AppLaunch/Hot"

@interface NRMANamedValueProducer : NRMAMeasurementProducer <NRMAHarvestAware> {
    NSTimeInterval lastDataSendTimestamp;
    CPUTime lastCPUTime;
    BOOL lastCPUTimeIsValid;
}

- (void) generateMachineMeasurements;
@end
