//
//  NRMACrashDataWriter.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/7/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_WATCH
#import "PLCrashNamespace.h"
#import "PLCrashReport.h"
#endif
@interface NRMACrashDataWriter : NSObject

#if !TARGET_OS_WATCH
+ (BOOL) writeCrashReport:(PLCrashReport*)report
             withMetaData:(NSDictionary*)metaDictionary
        sessionAttributes:(NSDictionary*)attributes
          analyticsEvents:(NSArray*)events;
#endif
@end
