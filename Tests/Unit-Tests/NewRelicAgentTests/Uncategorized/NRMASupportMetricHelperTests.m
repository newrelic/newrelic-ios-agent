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

-(void)testEventAddedSupportMetric {
    [NRMASupportMetricHelper enqueueEventAddedMetric];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([helper.result isKindOfClass:[NRMANamedValueMeasurement class]], @"The result is not a named value.");
    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventAddedMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

-(void)testEventOverflowSupportMetric {
    [NRMASupportMetricHelper enqueueEventOverflowMetric];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventOverflowMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

-(void)testEventEvictedSupportMetric {
    [NRMASupportMetricHelper enqueueEventEvictedMetric];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventEvictedMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

-(void)testEventQueueSizeExceededSupportMetric {
    [NRMASupportMetricHelper enqueueEventQueueSizeExceededMetric];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventQueueSizeExceededMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

-(void)testEventQueueTimeExceededSupportMetric {
    [NRMASupportMetricHelper enqueueEventQueueTimeExceededMetric];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventQueueTimeExceededMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @1]), @"Value is not generated properly.");
}

-(void)testEventSizeUncompressedSupportMetric {
    [NRMASupportMetricHelper enqueueEventSizeUncompressedMetric:512];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventSizeUncompressedMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @512]), @"Value is not generated properly.");
}

-(void)testEventRecordedSupportMetric {
    [NRMASupportMetricHelper enqueueEventRecordedMetric:10 evicted:3];
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue synchronousDequeue];

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)helper.result);
    XCTAssertEqualObjects(measurement.name, kNRMAEventRecordedMetric, @"Name is not generated properly.");
    XCTAssertTrue(([measurement.value isEqual: @10]), @"Recorded value is not generated properly.");
    XCTAssertTrue(([measurement.additionalValue isEqual: @3]), @"Evicted additionalValue is not generated properly.");
}

@end
