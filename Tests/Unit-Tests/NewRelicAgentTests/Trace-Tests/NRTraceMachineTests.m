//
//  NRMATraceMachineTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRTraceMachineTests.h"
#import "NRMATraceController.h"
#import "NRMATraceMachine.h"
#import "NRMAThread.h"
#import <OCMock/OCMock.h>
#import "NRMAActivityTraceMeasurement.h"
#import "NRMAMeasurements.h"
#import "NRMAHarvestableTrace.h"
#import "NRMAHarvestableActivity.h"
#import "NRMACustomTrace.h"
#import "NRMAHarvestController.h"
#import <pthread.h>
#import "NRMAMethodProfiler.h"
#import "NRMATaskQueue.h"
#import "NRMAThreadLocalStore.h"
#import "NewRelic.h"
#import "NewRelicAgentInternal.h"
#import "NRMAFlags.h"
#import "NRGCDOverride.h"

@interface NRMATaskQueue ()
+ (NRMATaskQueue*) taskQueue;
@end

@interface NRMATraceController (asdf)
+ (void) setUnhealthyTraceTimeout:(NSUInteger)millseconds;
+ (void) setHealthyTraceTimeout:(NSUInteger) healthyTraceTimeout;
+ (void) completeTrace:(NRMATrace*)trace withExitTimestampMillis:(NSNumber*)exitTimestampMilliseconds;
@end

@interface NRMAThreadLocalStore (TMTests)
+ (NSMutableDictionary*)threadDictionaries;
+ (NSMutableDictionary *)currentThreadDictionary;
@end


@implementation NRMATraceMachineTests

- (void) setUp
{
    [NRLogger setLogLevels:NRLogLevelNone];

    // Other test classes can leave the shared agent in a shutdown state (e.g. tests
    // that call [NewRelic shutdown], which sets isShutdown permanently for the process).
    // Once shutdown, NRMATraceController refuses to start or complete traces, so activity
    // traces are never captured and helper.result stays nil. Reset the flag and ensure
    // interaction tracing is enabled so these tests are self-contained and order-independent.
    [NewRelicAgentInternal sharedInstance].isShutdown = NO;
    [NRMAFlags enableFeatures:NRFeatureFlag_InteractionTracing];

    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_Activity];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];
    [NRMATraceController startTracing:YES];
    [NRMAThread instrumentNSThread];
    trueValue = YES;
    falseValue = NO;
    harvestConfigurationObject = [OCMockObject niceMockForClass:[NRMAHarvestController class]];
    NRMAHarvesterConfiguration* config = [[NRMAHarvesterConfiguration alloc] init];
    config.at_capture = nil;
    config.collect_network_errors = YES;
    config.data_report_period= 60;
    config.error_limit = 3;
    config.report_max_transaction_age = 5;
    config.report_max_transaction_count = 2000;
    config.response_body_limit = 1024;
    config.stack_trace_limit = 2000;
    config.activity_trace_max_send_attempts = 2;
    config.activity_trace_min_utilization = 0; //need to set this to 0 so we can capture all the stuff.
    [NRMAHarvestController configuration].at_capture = [[NRMATraceConfigurations alloc] init];
    [NRMAHarvestController configuration].at_capture.maxTotalTraceCount = 1000;

    [[[harvestConfigurationObject stub] andReturn:config] configuration];


//    [[[[harvestConfigurationObject stub] classMethod] andReturnValue:[NSValue value:&trueValue withObjCType:@encode(BOOL)]] shouldCollectTraces];
//    [[[[harvestConfigurationObject stub] classMethod] andReturnValue:[NSValue value:&falseValue withObjCType:@encode(BOOL)]] shouldNotCollectTraces];

}

- (void) tearDown
{
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;
    [NRMAMeasurements shutdown];
    [harvestConfigurationObject stopMocking];

}

#pragma mark - Wait helpers

// Waits until `condition` returns YES or `timeoutSeconds` elapses, returning whether the
// condition was met. This replaces the old unbounded `while (cond) {}` busy-spins.
//
// Two important properties, both deliberate:
//   1. It is BOUNDED. A condition that never becomes true fails the test (via the caller's
//      assertion) instead of spinning a CPU core forever and hanging the whole suite — the
//      exact failure that happened on Xcode test retries in CI.
//   2. It does NOT pump the main run loop. The agent schedules its trace-timeout timers on
//      the main run loop, so pumping here would fire them and prematurely expire the
//      activity trace under test. The flags these waits watch are flipped from background
//      GCD queues, so a short main-thread sleep between checks is sufficient.
- (BOOL) waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeoutSeconds
{
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:timeoutSeconds];
    while (!condition()) {
        if ([deadline timeIntervalSinceNow] <= 0) {
            return NO;
        }
        [NSThread sleepForTimeInterval:0.01];
    }
    return YES;
}

// Like -waitForCondition:timeout: but DOES pump the main run loop on each iteration.
// Some traces (e.g. the activity trace in -testThreadCapture) are only completed when the
// trace machine's main-run-loop timers get a chance to fire, so those tests need the main
// thread to keep servicing its run loop while they wait. Bounded by `timeoutSeconds` so a
// trace that never completes fails the test instead of hanging the whole suite.
- (BOOL) pumpMainRunLoopUntilCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeoutSeconds
{
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:timeoutSeconds];
    while (!condition()) {
        if ([deadline timeIntervalSinceNow] <= 0) {
            return NO;
        }
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    return YES;
}


// Verifies that, while an activity trace is active, traced work performed on three different
// execution contexts is all captured as child segments of that trace:
//   1. a detached NSThread        -> "NRMATraceMachineTests#tracedThreadWork"
//   2. a GCD dispatch_async block -> "dispatch_async"
//   3. the main thread itself     -> "NRMATraceMachineTests#testThreadCapture"
- (void) testThreadCapture
{
    [NRMATraceController startTracing:YES];

    __block BOOL backgroundWorkDone = NO;
    dispatch_queue_t queue = dispatch_queue_create("com.newrelic.test.threadCapture", NULL);

    // 1. Detached NSThread that opens and closes its own traced method.
    [NSThread detachNewThreadSelector:@selector(tracedThreadWork) toTarget:self withObject:nil];

    // 3. Traced segment on the main thread.
    NR_TRACE_METHOD_START(NRTraceTypeNone);

    // 2. Traced work dispatched onto a GCD queue. We dispatch rather than run inline so the
    //    main thread stays free to pump its run loop, which lets the trace machine complete
    //    the activity trace automatically.
    dispatch_async(queue, ^{
        [self busyWork];
        backgroundWorkDone = YES;
    });

    NR_TRACE_METHOD_STOP

    // Wait (pumping the main run loop) for the background work to finish and the activity
    // trace to be captured. Bounded so a stuck trace fails fast instead of hanging the suite.
    BOOL captured = [self pumpMainRunLoopUntilCondition:^BOOL{
        return backgroundWorkDone && helper.result != nil;
    } timeout:20.0];

    XCTAssertTrue(captured, @"timed out waiting for the activity trace to be captured");
    XCTAssertNotNil(helper.result, @"an activity trace should have been created");
    XCTAssertTrue([helper.result isKindOfClass:[NRMAActivityTraceMeasurement class]],
                  @"the captured measurement should be an activity trace");

    NRMAActivityTraceMeasurement* measurement = (NRMAActivityTraceMeasurement*)helper.result;

    // Every captured child segment should correspond to one of the three contexts above.
    NSSet* expectedNames = [NSSet setWithArray:@[
        @"NRMATraceMachineTests#tracedThreadWork",
        @"dispatch_async",
        @"NRMATraceMachineTests#testThreadCapture",
    ]];
    for (NRMATrace* trace in measurement.rootTrace.children.allObjects) {
        XCTAssertTrue([expectedNames containsObject:trace.name],
                      @"unexpected captured trace name: %@", trace.name);
    }

    // The captured trace should serialize to JSON without throwing.
    NRMAHarvestableActivity* harvestableActivity = [[NRMAHarvestableActivity alloc] init];
    harvestableActivity.name = measurement.traceName;
    harvestableActivity.startTime = measurement.startTime;
    harvestableActivity.endTime = measurement.endTime;
    [harvestableActivity.childSegments addObject:[[NRMAHarvestableTrace alloc] initWithTrace:measurement.rootTrace]];
    XCTAssertNoThrow((void)[harvestableActivity JSONObject], @"the captured trace should serialize to JSON");
}

// Short burst of CPU work, run on a background GCD queue, so the dispatch_async block
// produces a measurable traced segment.
- (void) busyWork
{
    for (int i = 1; i < 10000; i++) {
        volatile int w = 1;
        w += i;
    }
}

// Traced work performed on a detached NSThread.
- (void) tracedThreadWork
{
    NR_TRACE_METHOD_START(NRTraceTypeNone);
    @autoreleasepool {
        // Stay busy briefly so the segment is captured with a measurable duration.
        sleep(1);
        for (int i = 1; i < 10000; i++) {
            volatile int w = 1;
            w += i;
        }
    }
    NR_TRACE_METHOD_STOP;
}

- (void) testCustomActivity
{
    [NRMATraceController startTracing:YES];
    helper.result = nil;
    [NewRelic startInteractionWithName:@"Test"];

    // Let the interaction accrue for ~1s before completing it, while keeping the main
    // thread busy. This mirrors the original test, which relied on a hot main thread so
    // background harvest work wouldn't complete/expire the activity trace early — replacing
    // the spin with a plain sleep() makes this test fail with a nil result.
    //
    // The original code gated the 1s delay behind a *static* dispatch_once_t and then spun
    // on the flag it set. Because the token is per-process but the flag is recreated every
    // call, a second run of this test in the same process (e.g. an Xcode retry of a failed
    // run) skipped the block, never cleared the flag, and spun a CPU core forever — hanging
    // the whole suite. Dispatching the delay every time fixes that, and the deadline caps
    // the spin so it can never hang again.
    __block BOOL wait = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        wait = NO;
    });
    NSDate* spinDeadline = [NSDate dateWithTimeIntervalSinceNow:10.0];
    while (wait && [spinDeadline timeIntervalSinceNow] > 0) {}

    [NRMATraceController completeActivityTrace];
    [NRMATaskQueue synchronousDequeue];
    XCTAssertEqualObjects(((NRMAActivityTraceMeasurement*)helper.result).traceName, @"Test", @"");
}


- (void) testUnhealthyTrace
{
    [NRMATraceController completeActivityTrace];
    helper.result = nil;

    [NRMATraceController startTracing:YES];
    [NRMATraceController enterMethod:@selector(unhealthy)
                     fromObjectNamed:NSStringFromClass(self.class)
                         parentTrace:[NRMATraceController currentTrace]
                       traceCategory:NRTraceTypeNone];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sleep(1);
    });
    [NRMATraceController completeActivityTrace];

    [NRMATaskQueue synchronousDequeue];
    NSLog(@"%@",helper.result);

    XCTAssertTrue(helper.result, @"assert we got a result");


    NSSet* children = ((NRMAActivityTraceMeasurement*)helper.result).rootTrace.children;
    NRMATrace* unhealthyTrace = (NRMATrace*)[children anyObject];

    XCTAssertTrue([children count]  == 1, @"assert we have a child");
    NSString* name = [[children anyObject] name];
    NSString* expected = [NSString stringWithFormat:@"%@#unhealthy",NSStringFromClass(self.class)];
    XCTAssertEqualObjects(name, expected , @"assert we have the correct item");


    XCTAssertTrue(unhealthyTrace.exitTimestamp == 0, @"no endtime, because we didn'tOCMock finish");
}


- (void) testNodeLimit
{
    [NRMATraceController startTracing:YES];
    for (int i = 0; i < 2010; i++) {
        [NRMATraceController enterMethod:@selector(test)
                         fromObjectNamed:NSStringFromClass(self.class)
                             parentTrace:[NRMATraceController currentTrace]
                           traceCategory:NRTraceTypeNone];
//        NSLog(@"Logging to add cycles");
        [NRMATraceController exitMethod];
    }

    [NRMATraceController completeActivityTrace];

    [NRMATaskQueue synchronousDequeue];

    NSUInteger nodeCount = [((NRMAActivityTraceMeasurement*)helper.result).rootTrace.children count];
    XCTAssertEqual(nodeCount, (NSUInteger)2000, @"node count should be limited to 2000");
}

- (void) testAssignThreadDictionary
{
}

- (void) testTransTraceGCDCalls
{
    [NRMATraceController completeActivityTrace];
    helper.result = nil;

    [NRMATraceController startTracing:YES];
    NRTimer* timer = [NRTimer new];
    [NewRelic startTracingMethod:_cmd object:self timer:timer category:NRTraceTypeImages];
    dispatch_queue_t myqueue = dispatch_queue_create("pwd", NULL);
    __block BOOL finished = NO;
    dispatch_async(myqueue, ^{
        sleep(6);
        finished = YES;
    });
    __block BOOL finished2 = NO;
    dispatch_async(myqueue, ^{
        while (CFRunLoopGetCurrent() && !finished) {};
        finished2 = YES;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NRMAThreadLocalStore currentThreadDictionary] removeAllObjects];
        });
    });
    sleep(1);
    [NewRelic endTracingMethodWithTimer:timer];
    [NRMATraceController completeActivityTrace];

    [NRMATraceController startTracing:YES];

    // Bounded wait for the background work to finish (was an unbounded non-pumping spin).
    [self waitForCondition:^BOOL{ return finished2; } timeout:15.0];
    sleep(4);
    [NRMATraceController completeActivityTrace];
}

- (void)testPopCurrentCalled
{
    id exitTraceMock = [OCMockObject niceMockForClass:[NRMAThreadLocalStore class]];
    [[exitTraceMock expect] popCurrentTraceIfEqualTo:OCMOCK_ANY returningParent:[OCMArg anyObjectRef]];//we don't want this called
    __block BOOL done = NO;

    XCTAssertTrue([NRMATraceController isTracingActive], @"tracing should be active at this time");

    dispatch_queue_t queue = dispatch_queue_create("meeh", NULL);
    dispatch_async(queue, ^{
        done = YES;
    });

    XCTAssertTrue([self waitForCondition:^BOOL{ return done; } timeout:10.0],
                  @"timed out waiting for the dispatched block to run");
    sleep(1); // give the dispatch async to actually run "completion" code

    [NRMATraceController completeActivityTrace];
    [NRMATaskQueue synchronousDequeue];
    XCTAssertNoThrow([exitTraceMock verify], @"This should have been called");

    [exitTraceMock stopMocking];

}
- (void) testTraceConsistency
{
    //traces started in an old activity shouldn't be picked up by a new one.
    id exitTraceMock = [OCMockObject niceMockForClass:[NRMAThreadLocalStore class]];
    [[exitTraceMock expect] popCurrentTraceIfEqualTo:OCMOCK_ANY returningParent:[OCMArg anyObjectRef]];//we don't want this called
    __block BOOL started = NO;
    __block BOOL wait = YES;
    __block NSString* pid = nil;

    NRMAActivityTrace* old_at = [NRMATraceController currentTrace].traceMachine.activityTrace;
    XCTAssertTrue([NRMATraceController isTracingActive], @"tracing should be active at this time");

    dispatch_queue_t queue = dispatch_queue_create("meeh", NULL);
    dispatch_async(queue, ^{
        started = YES;
        pid = [NSString stringWithFormat:@"%d",pthread_mach_thread_np(pthread_self())];
        // Keep this background "trace" open until the main thread releases it below, so we
        // can verify a new activity doesn't adopt work started under the old one.
        while (CFRunLoopGetCurrent() && wait) { }
    });

    XCTAssertTrue([self waitForCondition:^BOOL{ return started; } timeout:10.0],
                  @"timed out waiting for the background trace to start");
    [NRMATraceController completeActivityTrace];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertFalse([NRMATraceController isTracingActive], @"tracing should NOT be active at this time");

    [NRMATraceController startTracing:YES];
    NRMAActivityTrace* at = [NRMATraceController currentTrace].traceMachine.activityTrace;

    XCTAssertFalse(at == old_at, @"traces should not be equal");

    wait = NO;
    sleep(1); // give the dispatch async to actually run "completion" code

    [NRMATraceController completeActivityTrace];
    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue(at.nodes == 0, @"we shouldn't pick-up the old async started in old trace");
    XCTAssertTrue([((NSDictionary*)[[NRMAThreadLocalStore threadDictionaries] objectForKey:pid]) count] == 0, @"the thread dictionary for the failed thread should be cleansed");
    XCTAssertThrows([exitTraceMock verify], @"This should not have been called");


    [exitTraceMock stopMocking];

}

- (void) testNRMAThreadTraceNoCrash
{
    XCTAssertNoThrow([NRMATraceController completeTrace:nil withExitTimestampMillis:[NSNumber numberWithDouble:123]], @"");

    NRMATrace* trace = [[NRMATrace alloc] initWithName:@"Mrow" traceMachine:nil];
    XCTAssertNoThrow([NRMATraceController completeTrace:trace withExitTimestampMillis:[NSNumber numberWithDouble:123123]], @"");
}

- (void) TestThreadLocalTraceCrash
{
    [NRMATraceController completeActivityTrace]; //in case there is an activity trace running

    [NRMATraceController enterMethod:_cmd
                     fromObjectNamed:NSStringFromClass(self.class)
                         parentTrace:nil
                       traceCategory:NRTraceTypeNone];
    {
        [NRMATraceController startTracing:YES];

        [NRMATraceController enterMethod:@selector(innerMethod)
                         fromObjectNamed:NSStringFromClass(self.class)
                             parentTrace:nil
                           traceCategory:NRTraceTypeNone];
        
        [NRMATraceController exitMethod]; //ok
    }
    
    XCTAssertNoThrow([NRMATraceController exitMethod],@"this shouldn't crash"); //crash
    
    [NRMATraceController completeActivityTrace];
}

@end
