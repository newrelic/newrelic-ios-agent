//
//  NRMAHarvestController.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/18/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRMAMethodSwizzling.h"
#import <OCMock/OCMock.h>
#import <objc/runtime.h>
#import "NRAgentTestBase.h"
#import "NRMAMeasurements.h"
#import "NRMAAppToken.h"
#import "NewRelicAgentInternal.h"
#import "NewRelic.h"
#import <NewRelic/NewRelic-Swift.h>

@interface NewRelicAgentInternal(UnitTests)

- (void)destroyAgent;

@end

@interface NRMAHarvestAwareTester : NSObject <NRMAHarvestAware>
@end
@implementation NRMAHarvestAwareTester

- (void) onHarvest
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}
- (void) onHarvestBefore
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}
- (void) onHarvestComplete
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}

- (void) onHarvestError
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}

- (void) onHarvestStart
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}

- (void) onHarvestStop
{
    @throw [NSException exceptionWithName:@"onHarvest" reason:@"" userInfo:nil];
}


@end

@interface NRMAHarvestControllerTest : NRMAAgentTestBase
{
}
@end

@interface NRMAHarvester (test)
- (void) clearStoredHarvesterConfiguration;
- (NRMAHarvesterConnection*)connection;
@end

@interface NRMAHarvestTimer (test)
- (void) tick;
@end


@implementation NRMAHarvestControllerTest

- (void)setUp
{
    [super setUp];
    
    // Put setup code here; it will be run once, before the first test case.
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                          collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                              crashAddress:nil];
    [NRMAHarvestController initialize:agentConfig];
    [[[NRMAHarvestController harvestController] harvester] clearStoredHarvesterConfiguration];
    [[[NRMAHarvestController harvestController] harvester] execute];
    [NRMAMeasurements initializeMeasurements];
    while (CFRunLoopGetCurrent() && [[NRMAHarvestController harvestController] harvester].currentState == NRMA_HARVEST_UNINITIALIZED) {};
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [NRMAMeasurements shutdown];
    [NRMAHarvestController stop];
    [super tearDown];
}
- (void) testVerifyCollectorTimestamp
{
    [[NRMAHarvestController harvestController] harvester].connection.serverTimestamp = 1234;

    [[[NRMAHarvestController harvestController] harvester] execute];
    NSURLRequest* request = [[[[NRMAHarvestController harvestController] harvester] connection] createDataPost:@"test"];

    NSString* timestampHeader = request.allHTTPHeaderFields[kCONNECT_TIME_HEADER];
    XCTAssertNotNil(timestampHeader, @"");
}


- (void) testHarvestControllerRecovery
{
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvestTimer* timer = [controller harvestTimer];
    NRMAHarvester* harvester =  [controller harvester];

    [NRMAHarvestController recovery];

    NRMAHarvestController* recoveredController = [NRMAHarvestController harvestController];
    NRMAHarvestTimer* recoveredTimer = [recoveredController harvestTimer];
    NRMAHarvester* recoveredHarvester = [recoveredController harvester];

    XCTAssertFalse(timer.timer.isValid, @"verify timer is invalidated");
    XCTAssertFalse(timer == recoveredTimer, @"verify the timer was reset");
    XCTAssertFalse(harvester == recoveredHarvester, @"verify the harvester was reset");
    XCTAssertFalse(controller == recoveredController, @"verify the controller was reset");

    timer = nil;
    harvester = nil;
    controller = nil;

}


- (void) testHarvestAwareException
{
    NRMAHarvestAwareTester* haware = [NRMAHarvestAwareTester new];
    [NRMAHarvestController addHarvestListener:haware];

    XCTAssertNoThrow([[[NRMAHarvestController harvestController] harvester] execute], @"assert no crash when harvest aware executes");

}

- (void) testHarvestTimerSessionTimeoutLogic
{
    // Test that the HarvestTimer's tick method correctly checks session duration
    // and triggers session restart when the timeout is exceeded

    // Initialize NewRelicAgentInternal singleton
    [NewRelic startWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN];

    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvestTimer* timer = [controller harvestTimer];
    NRMASessionDurationManager* sessionManager = [NRMASessionDurationManager shared];

    // Store original max duration to restore later
    NSTimeInterval originalMaxDuration = sessionManager.maxSessionDuration;

    // Configure session manager for a very short timeout (2 seconds)
    [sessionManager setMaxSessionDuration:2.0];

    // Set session start time to 5 seconds ago (well past the 2 second limit)
    NSDate* pastStartTime = [NSDate dateWithTimeIntervalSinceNow:-5.0];
    [sessionManager updateSessionStartTime:pastStartTime];

    // Verify session has exceeded before tick
    XCTAssertTrue([sessionManager hasSessionExceeded], @"Session should have exceeded the 2 second limit");

    // Mock NewRelicAgentInternal to verify handle4HourSessionRestart is called
    id mockAgentInternal = [OCMockObject partialMockForObject:[NewRelicAgentInternal sharedInstance]];
    [[mockAgentInternal expect] handle4HourSessionRestart];

    // Manually trigger the tick method (simulates harvest timer firing)
    [timer tick];

    // Wait for async dispatch to complete (tick uses dispatch_async)
    [NSThread sleepForTimeInterval:1.0];

    // Verify that handle4HourSessionRestart was called
    XCTAssertNoThrow([mockAgentInternal verify], @"handle4HourSessionRestart should have been called");

    // Clean up
    [mockAgentInternal stopMocking];

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
    
    [[NewRelicAgentInternal sharedInstance] destroyAgent];
}

- (void) testHarvestTimerSessionNotTimeoutWhenUnderLimit
{
    // Test that the HarvestTimer's tick method does NOT trigger restart
    // when session is still under the timeout limit

    // Initialize NewRelicAgentInternal singleton
    [NewRelic startWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN];

    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvestTimer* timer = [controller harvestTimer];
    NRMASessionDurationManager* sessionManager = [NRMASessionDurationManager shared];

    // Store original max duration to restore later
    NSTimeInterval originalMaxDuration = sessionManager.maxSessionDuration;

    // Configure session manager for 100 second timeout
    [sessionManager setMaxSessionDuration:100.0];

    // Set session start time to 10 seconds ago (under the 100 second limit)
    NSDate* recentStartTime = [NSDate dateWithTimeIntervalSinceNow:-10.0];
    [sessionManager updateSessionStartTime:recentStartTime];

    // Verify session has NOT exceeded before tick
    XCTAssertFalse([sessionManager hasSessionExceeded], @"Session should not have exceeded the 100 second limit");

    // Mock NewRelicAgentInternal to verify handle4HourSessionRestart is NOT called
    id mockAgentInternal = [OCMockObject partialMockForObject:[NewRelicAgentInternal sharedInstance]];
    [[mockAgentInternal reject] handle4HourSessionRestart];

    // Manually trigger the tick method (simulates harvest timer firing)
    [timer tick];

    // Wait for async dispatch to complete (tick uses dispatch_async)
    [NSThread sleepForTimeInterval:1.0];

    // Verify that handle4HourSessionRestart was NOT called
    XCTAssertNoThrow([mockAgentInternal verify], @"handle4HourSessionRestart should not have been called");

    // Clean up
    [mockAgentInternal stopMocking];

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
    
    [[NewRelicAgentInternal sharedInstance] destroyAgent];
}

- (void) testHarvestTimerSessionRestartResetsSessionDuration
{
    // Test that after a session restart triggered by the timer,
    // the session duration is properly reset

    NRMASessionDurationManager* sessionManager = [NRMASessionDurationManager shared];

    // Store original max duration
    NSTimeInterval originalMaxDuration = sessionManager.maxSessionDuration;

    // Configure session manager for short timeout
    [sessionManager setMaxSessionDuration:2.0];

    // Set session start time to past the limit
    NSDate* pastStartTime = [NSDate dateWithTimeIntervalSinceNow:-5.0];
    [sessionManager updateSessionStartTime:pastStartTime];

    // Verify session has exceeded
    XCTAssertTrue([sessionManager hasSessionExceeded], @"Session should have exceeded");
    NSTimeInterval oldDuration = [sessionManager currentSessionDuration];
    XCTAssertGreaterThan(oldDuration, 2.0, @"Old session duration should be over 2 seconds");

    // Simulate session restart by updating start time to now
    // (This is what handle4HourSessionRestart does via sessionStartInitialization)
    NSDate* newStartTime = [NSDate date];
    [sessionManager updateSessionStartTime:newStartTime];

    // Verify session no longer exceeds after restart
    XCTAssertFalse([sessionManager hasSessionExceeded], @"New session should not have exceeded");

    // Verify new session duration is very small
    NSTimeInterval newDuration = [sessionManager currentSessionDuration];
    XCTAssertLessThan(newDuration, 1.0, @"New session duration should be less than 1 second");

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
}

- (void) testHarvestTimerSessionRestartChangesSessionId
{
    // Test that the session ID changes after a 4-hour session restart

    // Initialize NewRelicAgentInternal singleton
    [NewRelic startWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN];

    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvestTimer* timer = [controller harvestTimer];
    NRMASessionDurationManager* sessionManager = [NRMASessionDurationManager shared];

    // Store original max duration to restore later
    NSTimeInterval originalMaxDuration = sessionManager.maxSessionDuration;

    // Configure session manager for a very short timeout (2 seconds)
    [sessionManager setMaxSessionDuration:2.0];

    // Set session start time to 5 seconds ago (well past the 2 second limit)
    NSDate* pastStartTime = [NSDate dateWithTimeIntervalSinceNow:-5.0];
    [sessionManager updateSessionStartTime:pastStartTime];

    // Get the session ID before restart
    NSString* sessionIdBefore = [[NewRelicAgentInternal sharedInstance] currentSessionId];
    XCTAssertNotNil(sessionIdBefore, @"Session ID should exist before restart");

    // Verify session has exceeded
    XCTAssertTrue([sessionManager hasSessionExceeded], @"Session should have exceeded the 2 second limit");

    // Manually trigger the tick method (simulates harvest timer firing)
    [timer tick];

    // Wait for async dispatch to complete and session restart to finish
    // The tick method uses dispatch_async and handle4HourSessionRestart does work
    [NSThread sleepForTimeInterval:2.0];

    // Get the session ID after restart
    NSString* sessionIdAfter = [[NewRelicAgentInternal sharedInstance] currentSessionId];
    XCTAssertNotNil(sessionIdAfter, @"Session ID should exist after restart");

    // Verify session ID has changed
    XCTAssertNotEqualObjects(sessionIdBefore, sessionIdAfter, @"Session ID should change after 4-hour restart");

    // Verify session duration has been reset
    NSTimeInterval durationAfter = [sessionManager currentSessionDuration];
    XCTAssertLessThan(durationAfter, 3.0, @"Session duration should be reset after restart");

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
    
    [[NewRelicAgentInternal sharedInstance] destroyAgent];
}

@end
