//
//  NRMACrashReportsManager.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/17/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PLCrashNamespace.h"
#import "PLCrashReporter.h"
@interface NRMACrashReportFileManager : NSObject

#if !TARGET_OS_WATCH
- (instancetype) initWithCrashReporter:(PLCrashReporter*)crashReporter;
#endif

- (void) processReportsWithSessionAttributes:(NSDictionary*)attributes
                             analyticsEvents:(NSArray*)events;
@end
