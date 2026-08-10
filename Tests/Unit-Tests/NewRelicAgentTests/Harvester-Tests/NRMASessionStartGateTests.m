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
@end

@implementation NRMASessionStartGateTests

- (void) setUp {
    [super setUp];

    // There is no custom -init on NewRelicAgentInternal, so this is NSObject's and runs
    // none of the agent start path -- exactly what we want. Stubbing +sharedInstance
    // follows Analytics-Tests/PersistentStoreTests.m:86-89.
    self.sharedInstanceMock = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    self.agent = [[NewRelicAgentInternal alloc] init];
    self.agent.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [[[[self.sharedInstanceMock stub] classMethod] andReturn:self.agent] sharedInstance];
}

- (void) tearDown {
    // The gate is a file static and survives between tests. Release it unconditionally so
    // one failing test cannot strand it and cascade into every later test.
    [self.agent endSessionStartDrainingDeferred];

    [self.sharedInstanceMock stopMocking];
    self.sharedInstanceMock = nil;
    self.agent = nil;

    [super tearDown];
}

#pragma mark - Gate primitive

- (void) test_gate_secondClaimFailsUntilReleased {
    XCTAssertTrue([self.agent tryBeginSessionStart], @"first claim should win the gate");
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

@end
