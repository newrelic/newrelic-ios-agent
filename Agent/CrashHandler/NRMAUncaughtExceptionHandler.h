//
//  NRMAUncaughtExceptionHandler.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/15/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_WATCH
#else
#import "PLCrashNamespace.h"
#import "PLCrashReporter.h"
#endif
@interface NRMAUncaughtExceptionHandler : NSObject
#if !TARGET_OS_WATCH
- (instancetype) initWithCrashReporter:(PLCrashReporter*)crashReporter;
#elif TARGET_OS_WATCH
- (instancetype) init;
#endif
- (BOOL) start;
- (BOOL) stop;

- (BOOL) isActive;
- (BOOL) isExceptionHandlerValid;
@end
