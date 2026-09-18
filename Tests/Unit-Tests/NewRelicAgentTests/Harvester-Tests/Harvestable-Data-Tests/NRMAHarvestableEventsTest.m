//
//  NRMAHarvestableEventsTest.m
//  NewRelic
//
//  Created by Bryce Buchanan on 2/10/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "NRMAAnalyticsEvents.h"
#import "NRMAHarvesterConfiguration.h"
#import "NRMAHarvestController.h"
#import <XCTest/XCTest.h>


@interface NRMAHarvestableEventsTest : XCTestCase
{
    NSArray * expectedJSON;
}
@property(strong) NRMAAnalyticsEvents* events;
@property(strong) id mockHarvestController;
@property(strong) NRMAHarvesterConfiguration* harvesterConfiguration;
@end

@implementation NRMAHarvestableEventsTest

- (void)setUp {
    [super setUp];
    self.events = [NRMAAnalyticsEvents new];
    expectedJSON = @[@{@"blah":@"blah"},@{@"pewpew":@4.4},@{@"event":@10,@"asdf":@"asdf",@"123":@123}];
    [self.events addEvents:expectedJSON];

    // The aging tests rely on a non-nil configuration; without one the production
    // code falls back to default/guard behavior and data never ages out on the
    // first pass. Mock +[NRMAHarvestController configuration] so the tests exercise
    // the real (non-nil) aging path with a known max_send_attempts of 0.
    self.harvesterConfiguration = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    self.harvesterConfiguration.activity_trace_max_send_attempts = 0;
    self.mockHarvestController = [OCMockObject mockForClass:[NRMAHarvestController class]];
    [[[[self.mockHarvestController stub] classMethod] andReturn:self.harvesterConfiguration] configuration];
}

- (void)tearDown {
    [self.mockHarvestController stopMocking];
    self.mockHarvestController = nil;
    self.harvesterConfiguration = nil;
    self.events = nil;
    [super tearDown];
}


- (void) testAddEvents {
    XCTAssertTrue([self.events count] == 3, @"we just added 3 events.");

   NSArray* json = [self.events JSONObject];

    for (int i = 0; i < expectedJSON.count; i++) {
        for (id obj in [expectedJSON[i] allKeys]) {
            XCTAssertTrue([expectedJSON[i][obj] isEqual:json[i][obj]],@"expected json is not equal to actual output: json[%@] = %@ doesn't match expectedJSON[%@] = %@",obj,json[i][obj],obj,expectedJSON[i][obj]);
        }
    }

    [self.events clear];

    XCTAssertTrue(self.events.count == 0, @"expected clear to remove all events.");

    XCTAssertNoThrow([self.events addEvents:nil], @"nil shouldn't throw.");
}


- (void) testEventAgedOutWithHarvestBefore
{
    XCTAssertTrue([self.events count] == 3, @"we just added 3 events.");

    NRMAHarvesterConfiguration *config = [NRMAHarvestController configuration];
    int maxSendAttempts = config.activity_trace_max_send_attempts; //this is 0

    for (int i = 0; i < maxSendAttempts+1; i++){
        [self.events onHarvestBefore];
    }

    XCTAssertTrue(self.events.count == 0, @"our data should have aged out.");
}


- (void) testEventAgedOutWithHarvestError
{
    XCTAssertTrue([self.events count] == 3, @"we just added 3 events.");

    NRMAHarvesterConfiguration *config = [NRMAHarvestController configuration];
    int maxSendAttempts = config.activity_trace_max_send_attempts; //this is 0

    for (int i = 0; i < maxSendAttempts+1; i++){
        [self.events onHarvestError];
    }

    XCTAssertTrue(self.events.count == 0, @"our data should have aged out.");
}
@end
