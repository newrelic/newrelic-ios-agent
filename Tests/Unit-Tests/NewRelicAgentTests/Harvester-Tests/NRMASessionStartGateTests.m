//
//  NRMASessionStartGateTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRAgentTestBase.h"
#import "NewRelicAgentInternal.h"
#import "NRMAAnalytics.h"
#import <NewRelic/NewRelic-Swift.h>
#include <stdatomic.h>

// The session-start gate and the funnel it guards are private to
// NewRelicAgentInternal.m. Declaring them here makes them visible to these tests and
// gives OCMock the method signatures it needs to stub them. Objective-C dispatches
// dynamically, so no production header change is required.
@interface NewRelicAgentInternal (SessionStartGateTests)
- (BOOL) tryBeginSessionStart;
- (void) endSessionStartDrainingDeferred;
- (void) performSessionStartInitialization;
// Defined at NewRelicAgentInternal.m:893 but declared in neither the header nor the class
// extension, so the 4-hour restart tests cannot see it without this.
- (void) handle4HourSessionRestart;
@end

@interface NRMASessionStartGateTests : NRMAAgentTestBase
@property (nonatomic, strong) NewRelicAgentInternal* agent;
@property (nonatomic, strong) id sharedInstanceMock;
@property (nonatomic, strong) id agentMock;
// Fulfilled by the shared -performSessionStartInitialization hook when set.
@property (atomic, strong) XCTestExpectation* sessionStartExpectation;
@end

@implementation NRMASessionStartGateTests {
    _Atomic int32_t _sessionStartCount;
    _Atomic int32_t _concurrentSessionStarts;
    _Atomic int32_t _maxConcurrentSessionStarts;
}

- (void) setUp {
    [super setUp];

    atomic_store(&_sessionStartCount, 0);
    atomic_store(&_concurrentSessionStarts, 0);
    atomic_store(&_maxConcurrentSessionStarts, 0);
    self.sessionStartExpectation = nil;

    // There is no custom -init on NewRelicAgentInternal, so this is NSObject's and runs
    // none of the agent start path -- exactly what we want. Stubbing +sharedInstance
    // follows Analytics-Tests/PersistentStoreTests.m:86-89.
    self.sharedInstanceMock = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    self.agent = [[NewRelicAgentInternal alloc] init];
    self.agent.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [[[[self.sharedInstanceMock stub] classMethod] andReturn:self.agent] sharedInstance];

    // Stub the real session start for every test in this class, and count the calls.
    //
    // Two reasons this is a shared stub rather than a per-test one. First, the real body
    // stops and rebuilds the whole harvest pipeline, which is not what any of these tests
    // are about. Second, releasing the gate re-dispatches deferred session starts
    // *asynchronously*: a test that deliberately causes a deferral hands off work that
    // lands after it has finished, and with no stub in place that work would run the real
    // body and hold the gate while the next test tried to claim it.
    self.agentMock = [OCMockObject partialMockForObject:self.agent];
    __weak __typeof__(self) weakSelf = self;
    [[[self.agentMock stub] andDo:^(NSInvocation* invocation) {
        [weakSelf noteSessionStartRan];
    }] performSessionStartInitialization];
}

- (void) tearDown {
    // The gate is a file static and outlives each test, so release it unconditionally.
    // This can re-dispatch a deferred session start onto a background queue, which lands
    // after this method returns.
    [self.agent endSessionStartDrainingDeferred];

    // Deliberately do NOT stop the agent partial mock, and do NOT release it or the agent.
    // The deferred session start above holds a strong reference to the agent and runs
    // later; if the stub were gone by then it would execute the real funnel body, which
    // rebuilds the harvest pipeline and pokes the session clock, corrupting whichever test
    // runs next. That is exactly the failure this suite hit. Leaving the stub installed
    // makes the late work a no-op. Each test builds its own agent and mock, so nothing is
    // shared between them, and XCTest keeps test instances alive for the whole run, so the
    // mock cannot be collected out from under a pending block. The only residue is a
    // transient gate hold, which -claimGate waits out.
    //
    // The +sharedInstance class mock is a different matter: it patches the class itself, so
    // it has to come off before the next test installs its own.
    [self.sharedInstanceMock stopMocking];
    self.sharedInstanceMock = nil;
    self.sessionStartExpectation = nil;

    [super tearDown];
}

#pragma mark - Helpers

// Called in place of the real -performSessionStartInitialization. Records that a session
// start ran, and tracks how many ran at once so the contention test can assert the gate
// never let two overlap.
- (void) noteSessionStartRan {
    int32_t now = atomic_fetch_add_explicit(&_concurrentSessionStarts, 1, memory_order_acq_rel) + 1;

    int32_t seen = atomic_load_explicit(&_maxConcurrentSessionStarts, memory_order_acquire);
    while (now > seen &&
           !atomic_compare_exchange_weak_explicit(&_maxConcurrentSessionStarts, &seen, now,
                                                  memory_order_acq_rel, memory_order_acquire)) {
        // A failed exchange reloads `seen`, so the loop re-tests against the new value.
    }

    atomic_fetch_add_explicit(&_sessionStartCount, 1, memory_order_acq_rel);
    atomic_fetch_sub_explicit(&_concurrentSessionStarts, 1, memory_order_acq_rel);

    [self.sessionStartExpectation fulfill];
}

- (int32_t) sessionStartCount {
    return atomic_load_explicit(&_sessionStartCount, memory_order_acquire);
}

- (int32_t) maxConcurrentSessionStarts {
    return atomic_load_explicit(&_maxConcurrentSessionStarts, memory_order_acquire);
}

// Claims the gate, tolerating a brief window in which a previous test's deferred session
// start is still finishing on a background queue. That transient hold is real gate
// behaviour rather than a test artifact, so waiting for it is the honest thing to do.
- (BOOL) claimGate {
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    do {
        if ([self.agent tryBeginSessionStart]) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.005];
    } while ([deadline timeIntervalSinceNow] > 0);
    return NO;
}

#pragma mark - Gate primitive

- (void) test_gate_secondClaimFailsUntilReleased {
    XCTAssertTrue([self claimGate], @"first claim should win the gate");
    XCTAssertFalse([self.agent tryBeginSessionStart], @"second claim should lose while held");

    [self.agent endSessionStartDrainingDeferred];

    XCTAssertTrue([self.agent tryBeginSessionStart], @"claim should win again after release");
    [self.agent endSessionStartDrainingDeferred];
}

- (void) test_gate_onlyOneClaimSucceedsUnderContention {
    const NSUInteger threadCount = 32;

    // Heap-allocated so the blocks below capture a pointer by value. A plain local would
    // be const-copied into each block, and __block plus _Atomic is needlessly subtle.
    _Atomic int32_t* winners = calloc(1, sizeof(_Atomic int32_t));

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger i = 0; i < threadCount; i++) {
        dispatch_group_async(group, queue, ^{
            if ([self.agent tryBeginSessionStart]) {
                atomic_fetch_add_explicit(winners, 1, memory_order_acq_rel);
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    XCTAssertEqual(atomic_load_explicit(winners, memory_order_acquire), 1,
                   @"exactly one of %lu concurrent claims may win the gate",
                   (unsigned long)threadCount);

    free(winners);
    [self.agent endSessionStartDrainingDeferred];
}

#pragma mark - Funnel

- (void) test_sessionStartInitialization_yieldsWhenGateHeld {
    XCTAssertTrue([self claimGate]);

    [self.agent sessionStartInitialization];

    XCTAssertEqual([self sessionStartCount], 0,
                   @"session start must not run while another one holds the gate");
}

- (void) test_deferredSessionStart_runsOnRelease {
    self.sessionStartExpectation =
        [self expectationWithDescription:@"deferred session start runs after release"];

    XCTAssertTrue([self claimGate]);
    [self.agent sessionStartInitialization];         // loses, registers the deferral
    XCTAssertEqual([self sessionStartCount], 0, @"nothing should have run yet");

    [self.agent endSessionStartDrainingDeferred];    // releases, drains, re-dispatches

    [self waitForExpectations:@[self.sessionStartExpectation] timeout:5.0];
    XCTAssertEqual([self sessionStartCount], 1, @"the deferred session start should have run once");
}

#pragma mark - 4-hour restart

- (void) test_handle4HourSessionRestart_bailsBeforeAnySideEffectWhenGateHeld {
    // Asserting only that -performSessionStartInitialization did not run would prove
    // nothing: gating the funnel already makes the restart's session start yield, because
    // the restart calls that funnel. The stronger claim, and the one this task is for, is
    // that the restart gives up *before* ending the analytics session -- otherwise a
    // restart that loses the gate ends a session and never starts a replacement.
    // -newSession is the method's first side effect, so rejecting it pins the bail to the
    // top of the method.
    id analyticsMock = [OCMockObject partialMockForObject:self.agent.analyticsController];
    [[analyticsMock reject] newSession];

    XCTAssertTrue([self claimGate]);
    XCTAssertNoThrow([self.agent handle4HourSessionRestart]);

    [analyticsMock verify];
    XCTAssertEqual([self sessionStartCount], 0, @"the restart must not have restarted the session");

    [analyticsMock stopMocking];
}

- (void) test_skippedRestart_leavesClockUnadvanced {
    NRMASessionDurationManager* manager = [NRMASessionDurationManager shared];
    NSTimeInterval originalMax = manager.maxSessionDuration;

    [manager setMaxSessionDuration:2.0];
    [manager updateSessionStartTime:[NSDate dateWithTimeIntervalSinceNow:-5.0]];
    XCTAssertTrue([manager hasSessionExceeded], @"precondition: session must be over the limit");

    // Hold the gate so the restart has to yield.
    XCTAssertTrue([self claimGate]);
    XCTAssertNoThrow([self.agent checkAndHandleSessionTimeout]);

    XCTAssertTrue([manager hasSessionExceeded],
                  @"a restart that yielded must leave the clock alone so the next harvest retries");
    XCTAssertEqual([self sessionStartCount], 0, @"the restart must not have restarted the session");

    [manager setMaxSessionDuration:originalMax];
    [manager updateSessionStartTime:[NSDate date]];
}

#pragma mark - setUserId

- (void) test_startNewSessionForUserId_appliesUserIdWhenGateHeld {
    // Same reasoning as the 4-hour restart: the claim has to land before -newSession, or a
    // loser ends the current session and leaves it with no replacement. The user id must
    // still be applied, because the gate owner is itself starting a new session.
    id analyticsMock = [OCMockObject partialMockForObject:self.agent.analyticsController];
    [[analyticsMock reject] newSession];

    XCTAssertTrue([self claimGate]);
    XCTAssertNoThrow([self.agent startNewSessionForUserId:@"gate-test-user"]);

    [analyticsMock verify];
    XCTAssertEqual([self sessionStartCount], 0, @"setUserId must not have restarted the session");

    [analyticsMock stopMocking];

    NSString* attributes = [self.agent.analyticsController sessionAttributeJSONString];
    XCTAssertNotNil(attributes, @"session attributes should be readable");
    XCTAssertTrue([attributes containsString:@"gate-test-user"],
                  @"the user id must be applied even when the session restart yields, got: %@",
                  attributes);
}

#pragma mark - Concurrency

- (void) test_concurrentSessionStarts_neverOverlap {
    const NSUInteger threadCount = 16;
    const NSUInteger iterations  = 50;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger t = 0; t < threadCount; t++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                [self.agent sessionStartInitialization];
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    XCTAssertLessThanOrEqual([self maxConcurrentSessionStarts], 1,
                             @"the gate must never let two session starts overlap, saw %d",
                             [self maxConcurrentSessionStarts]);
    XCTAssertGreaterThan([self sessionStartCount], 0,
                         @"sanity: at least one session start should have run");
}

@end
