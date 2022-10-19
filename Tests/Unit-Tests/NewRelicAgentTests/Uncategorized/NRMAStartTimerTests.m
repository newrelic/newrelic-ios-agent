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
#import "NRMATaskQueue.h"
#import "NRMASupportMetricHelper.h"

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@interface NRMAStartTimer ()
- (void)createDurationMetric;
@end

@implementation NRMAStartTimerTests

- (void) setUp {
    [super setUp];

    [NRMATaskQueue clear];

    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];

}

- (void) tearDown {
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;
    [NRMAMeasurements shutdown];
    
    [super tearDown];
}

-(void)test {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"systemBootTimestamp"];

    [[NRMAStartTimer sharedInstance] createDurationMetric];

    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    XCTAssertTrue([measurement.name isEqualToString:NRMA_METRIC_APP_LAUNCH_COLD], @"%@ does not equal AppLaunch/Cold", measurement.name);
}

@end
