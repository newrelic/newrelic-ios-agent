//
//  NRMASupportMetricHelperTests.m
//  Agent
//
//  Created by Chris Dillard on 9/8/22.
//  Copyright © 2023 New Relic. All rights reserved.
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

-(void)testAgentStopSupportMetric {

    [NRMASupportMetricHelper enqueueStopAgentMetric];

    [NRMASupportMetricHelper processDeferredMetrics];

    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([helper.result isKindOfClass:[NRMANamedValueMeasurement class]], @"The result is not a named value.");

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat:@"Supportability/Mobile/%@/Native/API/shutdown", [NewRelicInternalUtils osName]];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");
}

-(void)testOfflinePayloadSupportMetric {

    [NRMASupportMetricHelper enqueueOfflinePayloadMetric:1];

    [NRMASupportMetricHelper processDeferredMetrics];

    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([helper.result isKindOfClass:[NRMANamedValueMeasurement class]], @"The result is not a named value.");
    
    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);

    NSString* fullMetricName = [NSString stringWithFormat: kNRMAOfflineSupportabilityFormatString, [NewRelicInternalUtils osName], [NewRelicInternalUtils stringFromNRMAApplicationPlatform:[NRMAAgentConfiguration connectionInformation].deviceInformation.platform], kNRMACollectorDest];
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

@end
