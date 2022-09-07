//
//  NRMAStartTimerTests.m
//  Agent
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import "NRMAStartTimerTests.h"
#import "NRMAStartTimer.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMeasurements.h"
#import "NRMAMeasurementEngine.h"

@interface NRMAMeasurements (tests)
+ (NRMAMeasurementEngine*) engine;
@end
@interface NRMAStartTimer ()
- (void)createDurationMetric;
@end

@implementation NRMAStartTimerTests

- (void) setUp {
    [super setUp];

    [NRMAMeasurements initializeMeasurements];
}

- (void) tearDown {
    [NRMAMeasurements shutdown];
    
    [super tearDown];
}

-(void)test {
    [[NRMAStartTimer sharedInstance] createDurationMetric];

    [[NRMAMeasurements engine].machineMeasurementsProducer generateMachineMeasurements];

    NSArray *measurements = [(NSMutableSet*)[NRMAMeasurements engine].machineMeasurementsProducer.producedMeasurements[[NSNumber numberWithInt:NRMAMT_NamedValue]] allObjects];

    for (NRMANamedValueMeasurement *measurement in measurements) {
        if ([measurement.name isEqualToString:NRMA_METRIC_APP_LAUNCH_COLD]) { return; }
    }

    XCTFail("Could not find expected AppLaunch metric.");
}

@end
