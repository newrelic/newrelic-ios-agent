//
//  NRMAMethodSwizzlingTest.m
//  Agent_Tests
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "NRMAMethodSwizzling.h"

@interface NRMASwizzlingTestDummy : NSObject
+ (NSString *)greet;
+ (NSString *)greetNeverSwizzled;
- (NSString *)greetInstance;
@end

@implementation NRMASwizzlingTestDummy
+ (NSString *)greet {
    return @"original-class";
}
// Swizzling via NRMASwapOrReplaceClassMethod/NRMASwapOrReplaceInstanceMethod is
// permanent for the process once applied -- there's no teardown that undoes
// it. +greet and -greetInstance below get swizzled by the tests exercising
// that path, so this selector exists solely for the "nothing was ever
// swizzled" case, to avoid depending on test execution order.
+ (NSString *)greetNeverSwizzled {
    return @"original-class-never-swizzled";
}
- (NSString *)greetInstance {
    return @"original-instance";
}
@end

// Stand-ins for the tracing wrapper NRMA__generateAndSwizzleMethod installs in
// production -- all that matters here is that they're distinguishable from
// the real implementations above.
static NSString *NRMASwizzlingTestReplacementClassGreet(id self, SEL _cmd) {
    return @"replaced-class";
}
static NSString *NRMASwizzlingTestReplacementInstanceGreet(id self, SEL _cmd) {
    return @"replaced-instance";
}

@interface NRMAMethodSwizzlingTest : XCTestCase
@end

@implementation NRMAMethodSwizzlingTest

- (void)testUnswizzledSelectorReturnsSelectorUnchanged {
    SEL original = @selector(greetNeverSwizzled);
    SEL resolved = NRMAUninstrumentedSelector([NRMASwizzlingTestDummy class], original);
    XCTAssertEqual(resolved, original);
}

- (void)testNilClassReturnsSelectorUnchanged {
    SEL original = @selector(greetNeverSwizzled);
    SEL resolved = NRMAUninstrumentedSelector(nil, original);
    XCTAssertEqual(resolved, original);
}

- (void)testSwizzledClassMethodResolvesToOriginalImplementation {
    Class klass = [NRMASwizzlingTestDummy class];
    SEL originalSelector = @selector(greet);
    SEL aliasSelector = NSSelectorFromString([NRMAMethodStoragePrefix stringByAppendingString:NSStringFromSelector(originalSelector)]);

    // Install the "tracing wrapper" under the alias first, then swap it in
    // under the original selector -- exactly the sequence
    // NRMA__generateAndSwizzleMethod uses in production. This leaves the real
    // original implementation reachable only via the alias.
    class_addMethod(object_getClass(klass), aliasSelector, (IMP)NRMASwizzlingTestReplacementClassGreet, "@@:");
    NRMASwapOrReplaceClassMethod(klass, originalSelector, aliasSelector);

    // Confirm the swizzle actually took effect.
    XCTAssertEqualObjects([klass greet], @"replaced-class");

    // The bypass must resolve to the alias, whose IMP is now the real original.
    SEL resolved = NRMAUninstrumentedSelector(klass, originalSelector);
    XCTAssertEqual(resolved, aliasSelector);

    Method m = class_getClassMethod(klass, resolved);
    NSString *(*func)(id, SEL) = (void *)method_getImplementation(m);
    XCTAssertEqualObjects(func(klass, resolved), @"original-class");
}

- (void)testSwizzledInstanceMethodResolvesToOriginalImplementation {
    Class klass = [NRMASwizzlingTestDummy class];
    SEL originalSelector = @selector(greetInstance);
    SEL aliasSelector = NSSelectorFromString([NRMAMethodStoragePrefix stringByAppendingString:NSStringFromSelector(originalSelector)]);

    class_addMethod(klass, aliasSelector, (IMP)NRMASwizzlingTestReplacementInstanceGreet, "@@:");
    NRMASwapOrReplaceInstanceMethod(klass, originalSelector, aliasSelector);

    NRMASwizzlingTestDummy *instance = [NRMASwizzlingTestDummy new];
    XCTAssertEqualObjects([instance greetInstance], @"replaced-instance");

    SEL resolved = NRMAUninstrumentedSelector(klass, originalSelector);
    XCTAssertEqual(resolved, aliasSelector);

    Method m = class_getInstanceMethod(klass, resolved);
    NSString *(*func)(id, SEL) = (void *)method_getImplementation(m);
    XCTAssertEqualObjects(func(instance, resolved), @"original-instance");
}

@end
