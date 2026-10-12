//
//  CrashTriggers.m
//  NRTestApp
//
//  See CrashTriggers.h. Each method intentionally crashes.
//

#import "CrashTriggers.h"

@implementation CrashTriggers

+ (void)crashUnrecognizedSelector {
    // Unrecognized selector sent to class -> NSInvalidArgumentException.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL missing = NSSelectorFromString(@"thisSelectorDoesNotExist");
    [(id)self performSelector:missing];
#pragma clang diagnostic pop
}

+ (void)crashArrayIndexOutOfBounds {
    NSArray *array = @[@"a", @"b", @"c"];
    id value = [array objectAtIndex:10]; // NSRangeException
    NSLog(@"unreachable: %@", value);
}

+ (void)crashInsertNilIntoArray {
    NSMutableArray *array = [NSMutableArray array];
    id object = nil; // via a variable so the compiler doesn't reject the nonnull arg
    [array addObject:object]; // NSInvalidArgumentException
}

+ (void)crashMutateWhileEnumerating {
    NSMutableArray *array = [@[@1, @2, @3, @4] mutableCopy];
    for (id obj in array) {
        [array removeObject:obj]; // NSGenericException: mutated while being enumerated
    }
}

+ (void)crashRemoveUnregisteredKVOObserver {
    NSObject *observed = [NSObject new];
    NSObject *observer = [NSObject new];
    // Never registered -> "Cannot remove an observer ... as it is not registered".
    [observed removeObserver:observer forKeyPath:@"someKeyPath"];
}

+ (void)crashUncaughtException {
    @throw [NSException exceptionWithName:@"NRTestUncaughtException"
                                  reason:@"Intentionally thrown uncaught exception from CrashTriggers"
                                userInfo:nil];
}

@end
