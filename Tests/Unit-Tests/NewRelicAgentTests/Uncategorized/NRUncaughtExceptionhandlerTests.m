//
//  NRMAUncaughtExceptionhandlerTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/15/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAUncaughtExceptionHandler.h"
#import "PLCrashReporter.h"
#import <sys/sysctl.h>
#import "NRLogger.h"

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
    static BOOL debuggerIsAttached = NO;

    static dispatch_once_t debuggerPredicate;
    dispatch_once(&debuggerPredicate, ^{
        struct kinfo_proc info;
        size_t info_size = sizeof(info);
        int name[4];

        name[0] = CTL_KERN;
        name[1] = KERN_PROC;
        name[2] = KERN_PROC_PID;
        name[3] = getpid();

        if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
            NRLOG_AGENT_VERBOSE(@"Checking for a running debugger via sysctl() failed: %s", strerror(errno));
            debuggerIsAttached = false;
        }

        if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0) {
            debuggerIsAttached = true;
            PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
            NRMAUncaughtExceptionHandler* handler = [[NRMAUncaughtExceptionHandler alloc] initWithCrashReporter:reporter];
           
            XCTAssertTrue([handler isExceptionHandlerValid], @"should be true with typical handler declaration case");
            XCTAssertFalse([handler isActive], @"should not start during testing");
            XCTAssertFalse([handler start], @"should not start during testing");
            XCTAssertFalse([handler stop], @"should not have started during testing");
        }
    });
    
    
    
         
    }
 //}

@end
