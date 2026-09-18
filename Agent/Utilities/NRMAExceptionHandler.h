//
//  NRMAExceptionHandler.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAExceptionHandler : NSObject
+ (void) logException:(NSException*)exception
                class:(NSString*)cls
             selector:(NSString*)sel;

/**
 Runs @c block inside an Obj-C @@try/@@catch. If @c block raises an NSException
 the method returns NO and writes a description into @c error (if non-null);
 otherwise returns YES. Used as a hard backstop for code paths that touch
 partially-deallocated UIKit / CoreGraphics state (e.g. Session Replay's
 view-hierarchy walk during a rootViewController swap — NR-566282).
 */
+ (BOOL) safelyRun:(NS_NOESCAPE void(^)(void))block
             error:(NSError * _Nullable * _Nullable)error;
@end
