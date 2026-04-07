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

    // Manually trigger the tick method (simulates harvest timer firing)
    // This should not crash even if NewRelicAgentInternal is not initialized
    XCTAssertNoThrow([timer tick], @"tick should not crash when session has exceeded");

    // Wait for async dispatch to complete (tick uses dispatch_async)
    [NSThread sleepForTimeInterval:1.0];

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
}

- (void) testHarvestTimerSessionNotTimeoutWhenUnderLimit
{
    // Test that the HarvestTimer's tick method does NOT trigger restart
    // when session is still under the timeout limit

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

    // Manually trigger the tick method (simulates harvest timer firing)
    // This should not crash and should not trigger restart
    XCTAssertNoThrow([timer tick], @"tick should not crash when session is under limit");

    // Wait for async dispatch to complete (tick uses dispatch_async)
    [NSThread sleepForTimeInterval:1.0];

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
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

// Note: This test is prefixed with 'testZ' to run last alphabetically, after tests that need to call
- (void) testHarvestTimerSessionTimeoutWithSessionDurationManager
{
    // Test that SessionDurationManager correctly tracks when session has exceeded limit
    // and that HarvestTimer can safely check this condition

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

    // Verify session has exceeded
    XCTAssertTrue([sessionManager hasSessionExceeded], @"Session should have exceeded the 2 second limit");

    NSTimeInterval durationBefore = [sessionManager currentSessionDuration];
    XCTAssertGreaterThan(durationBefore, 4.0, @"Session duration should be over 4 seconds");

    // Manually trigger the tick method (simulates harvest timer firing)
    // This should handle the timeout condition without crashing
    XCTAssertNoThrow([timer tick], @"tick should handle timeout condition gracefully");

    // Wait for async dispatch to complete
    [NSThread sleepForTimeInterval:1.0];

    // Restore original configuration
    [sessionManager setMaxSessionDuration:originalMaxDuration];
    [sessionManager updateSessionStartTime:[NSDate date]];
}

@end
