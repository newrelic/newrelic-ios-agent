//
//  NRMAAnalyticsControllerStressor.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 3/24/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NewRelic/NewRelicAgent.h"
#import "NRMAFlags.h"

@interface NRMAAnalyticsControllerCustomEventStressor : XCTestCase
{
}

@end

@implementation NRMAAnalyticsControllerCustomEventStressor

- (void)setUp {
    [super setUp];
    [NRMAFlags enableFeatures: NRFeatureFlag_NewEventSystem];
}

- (void) testStress {
    XCTAssertNoThrow([self stress],
                     @"Failed stress test");
}

- (void) stress {
    [NewRelicAgent startWithApplicationToken:@"xx-NRMA-xx"];
    
    for (int i = 0; i < 20000; i++) {
        if(i  % 1000 == 0) {
            NSLog(@"iteration: %d", i);
        }
        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE2" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE3" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];

        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE4" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE5" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelicAgent recordCustomEvent:@"MYEVENTTYPE6" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
    }
}

@end
