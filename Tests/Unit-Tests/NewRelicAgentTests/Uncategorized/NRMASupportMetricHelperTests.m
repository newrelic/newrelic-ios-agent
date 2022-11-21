//
//  NRMASupportMetricHelperTests.m
//  Agent
//
//  Created by Chris Dillard on 9/8/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import "NRMASupportMetricHelperTests.h"
#import "NRMASupportMetricHelper.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMeasurements.h"
#import "NRMATaskQueue.h"
#import "NRMAFLags.h"
#import "NewRelicInternalUtils.h"

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@implementation NRMASupportMetricHelperTests

- (void) setUp {
    [super setUp];

    [NRMATaskQueue clear];

    if (deferredMetrics != nil) {
        [deferredMetrics removeAllObjects];
        deferredMetrics = nil;
    }
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

-(void)testEnableFeatureAndDisableFeatureCreateSupportabilityMetrics {


    [NRMAFlags enableFeatures:NRFeatureFlag_SwiftInteractionTracing];
    // Called by harvester during real agent run.
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat:@"Supportability/Mobile/%@/Native/API/enableFeature/SwiftInteractionTracing", [NewRelicInternalUtils osName]];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");

}

@end
