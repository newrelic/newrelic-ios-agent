//
//  NRMAUncaughtExceptionhandlerTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/15/14.
//  Copyright (c) 2014 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAUncaughtExceptionHandler.h"
#import "PLCrashReporter.h"

@interface NRMAUncaughtExceptionhandlerTests : XCTestCase

@end

@implementation NRMAUncaughtExceptionhandlerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testRegisterUncaughtExceptionHandler
{
//    STAssertTrue([NRMAUncaughtExceptionHandler registerUncaughtExceptionHandler], @"failed to register uncaught exception handler!");
}

- (void) testUnregisterUncaughtExceptionhandler
{
//    STAssertTrue([NRMAUncaughtExceptionHandler unregisterUncaughtExceptionHandler],@"failed to unregister uncaught exception handler!");
}
- (void) testHandlerBehaviorDuringTesting {
     PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
     NRMAUncaughtExceptionHandler* handler = [[NRMAUncaughtExceptionHandler alloc] initWithCrashReporter:reporter];
     XCTAssertTrue([handler isExceptionHandlerValid], @"should be true with typical handler declaration case");
     XCTAssertFalse([handler isActive], @"should not start during testing");
     XCTAssertFalse([handler start], @"should not start during testing");
     XCTAssertFalse([handler stop], @"should not have started during testing");
 }

@end
