//
//  NRAutoCollectLogStressTest.m
//  Agent
//
//  Created by Mike Bruin on 11/4/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAStressTestHelper.h"
#import <objc/runtime.h>
#import "NRAgentTestBase.h"
#import "NRLoggerTests.h"
#import "NRLogger.h"
#import "NRMAFlags.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRAutoLogCollector.h"
#import <os/log.h>


@interface NRAutoCollectLogStressTest : NRMAAgentTestBase

@property(atomic) unsigned long long asyncStartedCounter;
@property(strong) dispatch_semaphore_t semaphore;
@property(atomic) unsigned long long asyncEndedCounter;
@end

@implementation NRAutoCollectLogStressTest

- (void)setUp
{
    [super setUp];
    [NRMAFlags enableFeatures: NRFeatureFlag_LogReporting];
    [NRLogger setLogTargets:NRLogTargetFile | NRLogTargetConsole];

    [NRLogger setLogLevels:NRLogLevelDebug];
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];

    [NRLogger setLogEntityGuid:@"Entity-Guid-XXXX"];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                     collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                         crashAddress:nil];
    [NRMAHarvestController initialize:config];

    [NRLogger clearLog];
}

- (void) incrementAsyncCounter
{
    static NSString* lock = @"mylock";
    @synchronized(lock) {
        self.asyncStartedCounter++;
    }
}
- (void)incrementAsyncEndedCounter
{
    static NSString* lock = @"myLock2";
    @synchronized(lock) {
        self.asyncEndedCounter++;
    }
}

- (void)tearDown
{
    [NRMAHarvestController stop];
    [super tearDown];
}

- (void) testStress
{
    XCTAssertNoThrow([self stress], @"failed stress test");
}


- (void) stress
{
    @autoreleasepool {
        int iterations = kNRMAIterations;
        for (int i = 0; i < iterations; i++) {
            @autoreleasepool {
                [self incrementAsyncCounter];
                //These semaphores prevent the dispatch_async calls from blowing out the stack
                //they would otherwise get queued faster than they could be execute
                //thus creating a huge growth in heap size.
                dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
                dispatch_async([NRMAStressTestHelper randomDispatchQueue], ^{
                    @autoreleasepool {
                        [self randomlyExecute];
                        [self incrementAsyncEndedCounter];
                    dispatch_semaphore_signal(self.semaphore);
                    }
                });
                [self incrementAsyncCounter];
                //These semaphores prevent the dispatch_async calls from blowing out the stack
                //they would otherwise get queued faster than they could be execute
                //thus creating a huge growth in heap size.
                dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
                dispatch_async([NRMAStressTestHelper randomDispatchQueue], ^{
                    @autoreleasepool {
                        [self incrementAsyncEndedCounter];
                    dispatch_semaphore_signal(self.semaphore);
                    }
                });
                
                if (i % 1000 == 0) {
                    while (CFRunLoopGetCurrent() && self.asyncEndedCounter < self.asyncStartedCounter) {}
                }
            }
        }
        while (CFRunLoopGetCurrent() && self.asyncEndedCounter < self.asyncStartedCounter) {}
    }
}


- (void) randomlyExecute
{
    int options = 3;

    switch (rand() % options) {
        case 0:
            NSLog(@"Test!!! NSLog");
            break;
        case 1:
            os_log(OS_LOG_DEFAULT, "Test!!! os_log");
            break;
        case 2:
            [self logRandomString];
            break;
        default:
            break;
    }

}

- (NSString *) generateRandomString:(NSUInteger) length {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];
    
    for (NSUInteger i = 0; i < length; i++) {
        u_int32_t randomIndex = arc4random_uniform((u_int32_t)[letters length]);
        unichar randomChar = [letters characterAtIndex:randomIndex];
        [randomString appendFormat:@"%C", randomChar];
    }
    
    return randomString;
}

- (void) logRandomString {
    // Generate a random length between 1 and 500
    NSUInteger randomLength = arc4random_uniform(500) + 1;
    
    // Generate a random string of the random length
    NSString *randomString = [self generateRandomString:randomLength];
    
    // Log the random string
    os_log(OS_LOG_DEFAULT, "\(randomString)");
}

@end
