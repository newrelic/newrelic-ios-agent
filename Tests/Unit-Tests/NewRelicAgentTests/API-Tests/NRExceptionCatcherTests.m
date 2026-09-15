// NRExceptionCatcherTests.m
#import <XCTest/XCTest.h>
#import "NRExceptionCatcher.h"

@interface NRExceptionCatcherTests : XCTestCase
@end

@implementation NRExceptionCatcherTests

- (void)testTryBlockReturnsYesWhenNoExceptionThrown {
    BOOL result = [NRExceptionCatcher tryBlock:^{
        // no-op
    } catchBlock:^(NSException *exception) {
        XCTFail(@"catchBlock should not run");
    }];
    XCTAssertTrue(result);
}

- (void)testTryBlockReturnsNoAndInvokesCatchBlockWhenExceptionThrown {
    __block BOOL caughtCalled = NO;
    __block NSString *caughtName = nil;
    BOOL result = [NRExceptionCatcher tryBlock:^{
        @throw [NSException exceptionWithName:@"TestException" reason:@"boom" userInfo:nil];
    } catchBlock:^(NSException *exception) {
        caughtCalled = YES;
        caughtName = exception.name;
    }];
    XCTAssertFalse(result);
    XCTAssertTrue(caughtCalled);
    XCTAssertEqualObjects(caughtName, @"TestException");
}

@end
