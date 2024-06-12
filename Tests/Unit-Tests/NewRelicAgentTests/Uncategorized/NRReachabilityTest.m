//
//  NRMAReachabilityTest.m
//  NewRelicAgent
//
//  Created by Saxon D'Aubin on 8/9/12.
//  Copyright © 2023 New Relic. All rights reserved.
//
//

#import "NRReachabilityTest.h"
#import "NRMAReachability.h"

#import "NewRelicInternalUtils.h"
#import "NRMAMethodSwizzling.h"
#if !TARGET_OS_TV && !TARGET_OS_WATCH
#import <CoreTelephony/CTCarrier.h>
#endif

#pragma mark Methods to override the NRMAReachability currentReachabilityStatus method

NRMANetworkStatus ReachableViaWWANMethod(void) {
    return ReachableViaWWAN;
}

#if !TARGET_OS_TV && !TARGET_OS_WATCH
CTCarrier* ReachableGetCarrierMethod(void) {
    return [[CTCarrier alloc] init];
}
#endif

NRMANetworkStatus NotReachableMethod(void) {
    return NotReachable;
}


@implementation NRMAReachabilityTest

// this tests is mainly just to increase code coverage - we don't call this api
-(void)testConnectionRequired
{
    NRMAReachability *r = [NRMAReachability reachability];

    XCTAssertFalse([r connectionRequired], @"");
}

-(void)testCarrierName
{
    // the caching is managed with static function-local variables
    // sleep before running the test to allow the cache to timeout
    sleep(1);

    NSString* carrier = [NewRelicInternalUtils carrierName];
#if !TARGET_OS_TV && !TARGET_OS_WATCH
    XCTAssertTrue([carrier isEqualToString:@"wifi"], @"Carrier :%@", carrier);
#endif
}

-(void)testCarrierNameReachableViaWWAN
{
    // the caching is managed with static function-local variables
    // sleep before running the test to allow the cache to timeout
    sleep(1);

    void* origMethod = NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), (IMP)ReachableViaWWANMethod);
    @try {
        NSString* carrier = [NewRelicInternalUtils carrierName];
#if !TARGET_OS_TV && !TARGET_OS_WATCH
        XCTAssertTrue([carrier isEqualToString:@"unknown"], @"Carrier should be 'unknown', but is actually '%@'", carrier);
#endif
    } @finally {
        NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), origMethod);
    }
}

#if !TARGET_OS_TV && !TARGET_OS_WATCH
-(void)testCarrierNameReachableViaWWANWithCarrierInfo
{
    // the caching is managed with static function-local variables
    // sleep before running the test to allow the cache to timeout
    sleep(1);

    void* origMethod = NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), (IMP)ReachableViaWWANMethod);
    void* origMethodGetCarrierInfo = NRMAReplaceInstanceMethod([NRMAReachability class], @selector(getCarrierInfo), (IMP)ReachableGetCarrierMethod);

    @try {
        NSString* carrier = [NewRelicInternalUtils carrierName];
        XCTAssertTrue([carrier isEqualToString:@"unknown"], @"Carrier should be 'unknown', but is actually '%@'", carrier);
    } @finally {
        NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), origMethod);
        NRMAReplaceInstanceMethod([NRMAReachability class], @selector(getCarrierInfo), origMethodGetCarrierInfo);
    }
}
#endif

-(void)testCarrierNameCache
{
    // the caching is managed with static function-local variables
    // sleep before running the test to allow the cache to timeout
    sleep(1);

    NSString *carrier;
    void* origMethod = NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), (IMP)ReachableViaWWANMethod);
    @try {
        carrier = [NewRelicInternalUtils carrierName];
#if !TARGET_OS_TV && !TARGET_OS_WATCH
        XCTAssertTrue([carrier isEqualToString:@"unknown"], @"Carrier should be 'unknown', but is actually '%@'", carrier);
#endif
    } @finally {
        NRMAReplaceInstanceMethod([NRMAReachability class], @selector(currentReachabilityStatus), origMethod);
    }

    // calling immediately should return 'other' as it's still cached
    carrier = [NewRelicInternalUtils carrierName];
#if !TARGET_OS_TV && !TARGET_OS_WATCH
    XCTAssertTrue([carrier isEqualToString:@"unknown"], @"Carrier should still be 'unknown', but is actually '%@'", carrier);
#endif
    // after a second our cache should have expired and we should get 'wifi' this time
    sleep(1);
    carrier = [NewRelicInternalUtils carrierName];
#if !TARGET_OS_TV && !TARGET_OS_WATCH
    XCTAssertTrue([carrier isEqualToString:@"wifi"], @"Carrier should have reverted to 'wifi', but is actually '%@'", carrier);
#endif
}

@end

// This stops tests from crashing - http://hamishrickerby.com/2012/04/05/unit-test-code-coverage-with-xcode-4-dot-3-2/

#import <stdio.h>
// Prototype declarations
FILE *fopen$UNIX2003( const char *filename, const char *mode );
size_t fwrite$UNIX2003( const void *a, size_t b, size_t c, FILE *d );

FILE *fopen$UNIX2003( const char *filename, const char *mode ) {
    return fopen(filename, mode);
}
size_t fwrite$UNIX2003( const void *a, size_t b, size_t c, FILE *d ) {
    return fwrite(a, b, c, d);
}

