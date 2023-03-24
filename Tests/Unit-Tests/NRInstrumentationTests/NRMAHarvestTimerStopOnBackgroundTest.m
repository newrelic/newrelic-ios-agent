//
//  NRMAHarvestTimerStopOnBackgroundTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/19/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NRAgentTestBase.h"
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMAAppToken.h"
#import <OCMock/OCMock.h>

@interface NewRelicAgentInternal ()
- (void) applicationDidEnterBackground;
@end 

@interface NRMAHarvestTimerStopOnBackgroundTest : NRMAAgentTestBase
@property(strong,atomic) NewRelicAgentInternal* agentInternal;
@end

@implementation NRMAHarvestTimerStopOnBackgroundTest

- (void)setUp {
    [super setUp];
    self.agentInternal = [[NewRelicAgentInternal alloc] init];


    NRMAAgentConfiguration* _agentConfiguration = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"APP_TOKEN"]
                                                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST crashAddress:nil];
    
    [NRMAHarvestController initialize:_agentConfiguration];
    [NRMAHarvestController start];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) testBackgroundDisableHarvestTimer
{
    //testing the harvest timer is stopped before the background harvest occurs.
    NSTimeInterval timout = 30;
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    while (CFRunLoopGetCurrent() &&
           ![[[[NRMAHarvestController harvestController] harvestTimer] timer] isValid] &&
           ([NSDate timeIntervalSinceReferenceDate] - startTime) < timout) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }

    XCTAssertTrue([[[[NRMAHarvestController harvestController] harvestTimer] timer] isValid], @"timer failed to start");
    id mockTimer = [OCMockObject partialMockForObject:[[NRMAHarvestController harvestController] harvestTimer]];
    [[mockTimer expect] stop];
    id mockHarester = [OCMockObject partialMockForObject:[[NRMAHarvestController harvestController]harvester]];
    [[[mockHarester stub] andDo:^(NSInvocation * invocation) {
        XCTAssertNoThrow([mockTimer verify], @"harvest timer not stopped before harvest.");
    }] execute];

    //simulate app backgrounding
    [self.agentInternal applicationDidEnterBackground];

    //stop mocking
    [mockTimer stopMocking];
    [mockHarester stopMocking];
}

- (void)tearDown {
    [NRMAHarvestController stop];
    [super tearDown];
}


@end
