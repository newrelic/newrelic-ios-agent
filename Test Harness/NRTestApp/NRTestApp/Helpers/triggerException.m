//
//  triggerException.m
//  NRTestApp
//
//  Created by Mike Bruin on 1/13/23.
//

#import "triggerException.h"
#import "NewRelic/NewRelic.h"

@implementation triggerException

+ (void) testing {
    @try {
        @throw [NSException exceptionWithName:@"testException"
                              reason:@"Intentionally created exception"
                            userInfo:nil];
    } @catch (NSException* e) {
        [NewRelic recordHandledException:e];
    }
}

+ (void) testNSLog {
    NSLog(@"TEST Objective C!!!!!");
}

@end
