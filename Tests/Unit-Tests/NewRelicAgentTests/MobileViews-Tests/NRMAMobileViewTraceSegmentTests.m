//
//  NRMAMobileViewTraceSegmentTests.m
//  Agent_Tests
//
//  A tracked view's load span, recorded as a segment on the interaction (activity trace) that
//  covers it. The segment is what puts the screen in the interaction's breakdown table: every
//  completed trace node emits a scoped `Method/<class>/<method>` metric, and that metric is the
//  row. It is recorded after the fact from timestamps the producers already hold, because a
//  segment held open from viewDidLoad to viewDidAppear would sit on the thread-local trace stack
//  across runloop turns and break the pop of every lifecycle frame in between.
//
//  These tests assert on what leaves the trace machine — the scoped metric and the summary
//  measurement — rather than on the shape of the in-memory trace tree, because the metric is
//  what the breakdown table is built from.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMATraceController.h"
#import "NRMATraceMachine.h"
#import "NRMAActivityTrace.h"
#import "NRMATrace.h"
#import "NRMACustomTrace.h"
#import "NRMAMeasurements.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMethodSummaryMeasurement.h"
#import "NRMeasurementConsumerHelper.h"
#import "NRMATaskQueue.h"
#import "NRMAHarvestController.h"
#import "NRMAMobileViewTracker.h"
#import "NRMAFlags.h"
#import "NewRelicInternalUtils.h"
#import "NRLogger.h"

@interface NRMATraceController (MobileViewTraceSegmentTests)
+ (NRMATraceMachine *)traceMachine;
@end

@interface NRMAMobileViewTraceSegmentTests : XCTestCase {
    BOOL _hadAutomaticMobileViews;
    NRMAMeasurementConsumerHelper *_metrics;   // the scoped Method/... metrics behind each row
    NRMAMeasurementConsumerHelper *_summaries; // per-segment category and timing
}
@end

@implementation NRMAMobileViewTraceSegmentTests

- (void)setUp {
    [super setUp];
    [NRLogger setLogLevels:NRLogLevelNone];
    [NRMAMeasurements initializeMeasurements];
    _metrics = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    _summaries = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_Method];
    [NRMAMeasurements addMeasurementConsumer:_metrics];
    [NRMAMeasurements addMeasurementConsumer:_summaries];
    [NRMAHarvestController configuration].at_capture.maxTotalTraceCount = 1000;
    _hadAutomaticMobileViews = [NRMAFlags shouldEnableAutomaticMobileViews];
    [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];
}

- (void)tearDown {
    if ([NRMATraceController isTracingActive]) {
        // cleanup rather than completeActivityTrace: tearing down must not harvest a trace.
        [NRMATraceController cleanup];
    }
    [NRMAMeasurements removeMeasurementConsumer:_metrics];
    [NRMAMeasurements removeMeasurementConsumer:_summaries];
    if (_hadAutomaticMobileViews) {
        [NRMAFlags enableFeatures:NRFeatureFlag_AutomaticMobileViews];
    } else {
        [NRMAFlags disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    }
    [NRMAMeasurements shutdown];
    [super tearDown];
}

#pragma mark - Helpers

- (void)recordProductDetailSegmentFrom:(double)entryMillis to:(double)exitMillis {
    [NRMATraceController recordCompletedSegmentWithObjectNamed:@"MobileView"
                                                  methodNamed:@"ProductDetail"
                                         entryTimestampMillis:entryMillis
                                          exitTimestampMillis:exitMillis
                                                traceCategory:NRTraceTypeMobileView];
}

/// The scoped metric a completed segment emits — one per breakdown row.
- (NRMANamedValueMeasurement *)metricNamed:(NSString *)name {
    [NRMATaskQueue synchronousDequeue];
    for (NRMAMeasurement *measurement in _metrics.consumedMeasurements) {
        if ([[measurement name] isEqualToString:name]) {
            return (NRMANamedValueMeasurement *)measurement;
        }
    }
    return nil;
}

/// The summary measurement a completed segment emits, carrying its category and timing.
- (NRMAMethodSummaryMeasurement *)summaryNamed:(NSString *)name {
    [NRMATaskQueue synchronousDequeue];
    for (NRMAMeasurement *measurement in _summaries.consumedMeasurements) {
        if ([[measurement name] isEqualToString:name]) {
            return (NRMAMethodSummaryMeasurement *)measurement;
        }
    }
    return nil;
}

- (NSArray<NRMATrace *> *)childrenOf:(NRMATrace *)trace {
    @synchronized (trace.children) {
        return [trace.children allObjects];
    }
}

/// Opens an instrumented method frame, as the profiler does around viewDidAppear:.
- (NRMATrace *)openMethodFrame {
    return [NRMATraceController enterMethod:@selector(viewDidAppear:)
                           fromObjectNamed:@"UIViewController"
                               parentTrace:[NRMATraceController currentTrace]
                             traceCategory:NRTraceTypeViewLoading];
}

#pragma mark - The category

// The category is what buckets the segment's time in the Mobile/Summary rollup the agent sends.
- (void)testTheMobileViewCategoryHasItsOwnMetricName {
    XCTAssertEqualObjects(NSStringFromNRMATraceType(NRTraceTypeMobileView), @"Views");
}

// Host apps compile NR_TRACE_METHOD_START(NRTraceTypeJson) against these raw values, so a new
// category has to be appended to the enum, never inserted among the existing ones.
- (void)testTheExistingCategoryRawValuesAreUnchanged {
    XCTAssertEqual(NRTraceTypeNone, 0);
    XCTAssertEqual(NRTraceTypeViewLoading, 1);
    XCTAssertEqual(NRTraceTypeLayout, 2);
    XCTAssertEqual(NRTraceTypeDatabase, 3);
    XCTAssertEqual(NRTraceTypeImages, 4);
    XCTAssertEqual(NRTraceTypeJson, 5);
    XCTAssertEqual(NRTraceTypeNetwork, 6);
    XCTAssertEqual(NRTraceTypeMobileView, 7);
}

#pragma mark - Recording a completed segment

// The metric name is the breakdown table's "Method name"; its scope is the interaction the row
// belongs to. Together they are the row.
- (void)testARecordedSegmentEmitsTheScopedMethodMetricThatIsTheBreakdownRow {
    [NRMATraceController startTracing:YES];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    NRMANamedValueMeasurement *metric = [self metricNamed:@"Method/MobileView/ProductDetail"];
    XCTAssertNotNil(metric, @"no metric means no row in the breakdown table");
    XCTAssertTrue([metric.scope hasPrefix:@"Mobile/Activity/Name/"],
                  @"the row has to be scoped to the interaction, got \"%@\"", metric.scope);
}

- (void)testTheSegmentsDurationComesFromTheTimestampsGivenNotTheTimeOfRecording {
    [NRMATraceController startTracing:YES];
    double appear = NRMAMillisecondTimestamp();
    double load = appear - 250;

    [self recordProductDetailSegmentFrom:load to:appear];

    NRMAMethodSummaryMeasurement *summary = [self summaryNamed:@"MobileView#ProductDetail"];
    XCTAssertNotNil(summary);
    XCTAssertEqual(summary.startTime, load);
    XCTAssertEqual(summary.endTime, appear);
}

- (void)testARecordedSegmentIsSummarizedUnderTheCategoryItWasGiven {
    [NRMATraceController startTracing:YES];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    XCTAssertEqual([self summaryNamed:@"MobileView#ProductDetail"].category, NRTraceTypeMobileView);
}

// A view name is host-app text and can hold characters that would split the metric name apart.
- (void)testAViewNameIsCleansedBeforeItBecomesPartOfTheMetricName {
    [NRMATraceController startTracing:YES];
    double appear = NRMAMillisecondTimestamp();

    [NRMATraceController recordCompletedSegmentWithObjectNamed:@"MobileView"
                                                  methodNamed:@"Cart/Checkout#2"
                                         entryTimestampMillis:appear - 10
                                          exitTimestampMillis:appear
                                                traceCategory:NRTraceTypeMobileView];

    XCTAssertNotNil([self metricNamed:@"Method/MobileView/Cart_Checkout_2"]);
}

- (void)testNothingIsRecordedWhenNoInteractionIsRunning {
    XCTAssertFalse([NRMATraceController isTracingActive], @"precondition");
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    XCTAssertNil([self metricNamed:@"Method/MobileView/ProductDetail"],
                 @"a segment describes work inside an interaction; there is none to attach to");
    XCTAssertFalse([NRMATraceController isTracingActive],
                   @"recording a segment must not start an interaction of its own");
}

// A recorded segment overlaps the instrumented methods it spans, so counting it as a child of the
// frame it was recorded from would subtract its whole span from that frame's exclusive time.
- (void)testARecordedSegmentDoesNotSwallowTheExclusiveTimeOfTheMethodItWasRecordedFrom {
    [NRMATraceController startTracing:YES];
    NRMATrace *frame = [self openMethodFrame];
    [NSThread sleepForTimeInterval:0.01];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];
    [NRMATraceController exitMethod];

    XCTAssertGreaterThan(frame.exclusiveTimeMillis, 5,
                         @"the frame ran for ~10ms of its own; a 250ms child would zero that out");
}

// Deliberate: the row comes from the metric, so the node is kept out of the harvested tree rather
// than inserted with a span that starts before its parent's and overlaps its siblings'.
- (void)testARecordedSegmentIsNotAddedToTheTraceTree {
    [NRMATraceController startTracing:YES];
    NRMATrace *frame = [self openMethodFrame];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    XCTAssertEqual([self childrenOf:frame].count, 0);
}

// The segment is opened and closed inside the one call. If it were left on the thread's trace
// stack, the next instrumented method to exit would fail its pop and lose its own segment.
- (void)testRecordingASegmentLeavesTheThreadsCurrentTraceWhereItWas {
    [NRMATraceController startTracing:YES];
    NRMATrace *before = [NRMATraceController currentTrace];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    XCTAssertEqualObjects([NRMATraceController currentTrace], before);
}

// A half-open node keeps the activity trace waiting on a child that never completes.
- (void)testARecordedSegmentIsNotLeftAsAMissingChildOfTheInteraction {
    [NRMATraceController startTracing:YES];
    double appear = NRMAMillisecondTimestamp();

    [self recordProductDetailSegmentFrom:appear - 250 to:appear];

    XCTAssertFalse([[NRMATraceController traceMachine].activityTrace hasMissingChildren]);
}

#pragma mark - The producers' recorder

// The producers hold CFAbsoluteTime; trace timestamps are milliseconds since the epoch. One
// conversion, in the recorder, so the two producers cannot drift apart on it.
- (double)epochMillisFromAbsoluteTime:(CFAbsoluteTime)absoluteTime {
    return (absoluteTime + kCFAbsoluteTimeIntervalSince1970) * 1000;
}

- (void)testALoadSpanIsRecordedAgainstTheInteractionInMillisecondsSinceTheEpoch {
    [NRMATraceController startTracing:YES];
    CFAbsoluteTime appear = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime load = appear - 0.25;

    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:@"ProductDetail"
                                               loadTime:load
                                             appearTime:appear];

    NRMAMethodSummaryMeasurement *summary = [self summaryNamed:@"MobileView#ProductDetail"];
    XCTAssertNotNil(summary);
    XCTAssertEqualWithAccuracy(summary.startTime, [self epochMillisFromAbsoluteTime:load], 0.001);
    XCTAssertEqualWithAccuracy(summary.endTime, [self epochMillisFromAbsoluteTime:appear], 0.001);
}

- (void)testALoadSpanIsRecordedUnderTheMobileViewCategoryAndMetricName {
    [NRMATraceController startTracing:YES];
    CFAbsoluteTime appear = CFAbsoluteTimeGetCurrent();

    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:@"ProductDetail"
                                               loadTime:appear - 0.25
                                             appearTime:appear];

    XCTAssertNotNil([self metricNamed:@"Method/MobileView/ProductDetail"]);
    XCTAssertEqual([self summaryNamed:@"MobileView#ProductDetail"].category, NRTraceTypeMobileView);
}

// A view that reappears without reloading has no load timestamp — its span is unknown, not zero.
- (void)testAViewWithNoLoadTimestampIsNotRecorded {
    [NRMATraceController startTracing:YES];

    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:@"ProductDetail"
                                               loadTime:0
                                             appearTime:CFAbsoluteTimeGetCurrent()];

    XCTAssertNil([self metricNamed:@"Method/MobileView/ProductDetail"],
                 @"an unknown load timestamp would otherwise span from 2001 to now");
}

- (void)testASpanThatEndsBeforeItStartsIsNotRecorded {
    [NRMATraceController startTracing:YES];
    CFAbsoluteTime appear = CFAbsoluteTimeGetCurrent();

    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:@"ProductDetail"
                                               loadTime:appear + 1
                                             appearTime:appear];

    XCTAssertNil([self metricNamed:@"Method/MobileView/ProductDetail"]);
}

// MobileViews data must not appear while the feature is off, and the segment is MobileViews data.
- (void)testNoLoadSpanIsRecordedWhileTheAutomaticMobileViewsFeatureIsDisabled {
    [NRMAFlags disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMATraceController startTracing:YES];
    CFAbsoluteTime appear = CFAbsoluteTimeGetCurrent();

    [NRMAMobileViewTracker recordLoadSegmentForViewNamed:@"ProductDetail"
                                               loadTime:appear - 0.25
                                             appearTime:appear];

    XCTAssertNil([self metricNamed:@"Method/MobileView/ProductDetail"]);
}

@end
