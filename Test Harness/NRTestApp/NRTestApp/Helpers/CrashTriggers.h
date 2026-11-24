//
//  CrashTriggers.h
//  NRTestApp
//
//  Objective-C / Foundation / UIKit crash triggers used by the
//  "UIKit Crashes" test screen to validate New Relic crash reporting.
//  Every method below crashes the process immediately (uncaught
//  NSException -> SIGABRT), so they are intended to be called from a
//  build that is NOT attached to the Xcode debugger.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CrashTriggers : NSObject

/// Sends a selector the receiver does not implement -> NSInvalidArgumentException (SIGABRT).
+ (void)crashUnrecognizedSelector;

/// Reads one past the end of an NSArray -> NSRangeException (SIGABRT).
+ (void)crashArrayIndexOutOfBounds;

/// Inserts nil into an NSMutableArray -> NSInvalidArgumentException (SIGABRT).
+ (void)crashInsertNilIntoArray;

/// Mutates an NSMutableArray while fast-enumerating it -> NSGenericException (SIGABRT).
+ (void)crashMutateWhileEnumerating;

/// Removes a KVO observer that was never registered -> NSRangeException (SIGABRT).
+ (void)crashRemoveUnregisteredKVOObserver;

/// Throws an uncaught NSException -> SIGABRT.
+ (void)crashUncaughtException;

@end

NS_ASSUME_NONNULL_END
