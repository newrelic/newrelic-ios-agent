//
//  NRMAAnalyticsControllerStressor.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 3/24/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NewRelic/NewRelic.h"

@interface NRMAAnalyticsControllerCustomEventStressor : XCTestCase
{
}

@end

@implementation NRMAAnalyticsControllerCustomEventStressor

- (void)setUp {
    [super setUp];
}

- (void) testStress {
    XCTAssertNoThrow([self stress],
                     @"Failed stress test");
}

- (void) stress {
    [NewRelic startWithApplicationToken:@"xx-NRMA-xx"];
    
    for (int i = 0; i < 20000; i++) {
        if(i  % 1000 == 0) {
            NSLog(@"iteration: %d", i);
        }
        [NewRelic recordCustomEvent:@"MYEVENTTYPE" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelic recordCustomEvent:@"MYEVENTTYPE2" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelic recordCustomEvent:@"MYEVENTTYPE3" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];

        [NewRelic recordCustomEvent:@"MYEVENTTYPE4" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelic recordCustomEvent:@"MYEVENTTYPE5" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
        [NewRelic recordCustomEvent:@"MYEVENTTYPE6" name: [[NSUUID UUID] UUIDString] attributes:@{[[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]: [[NSUUID UUID] UUIDString]}];
    }
}

@end
