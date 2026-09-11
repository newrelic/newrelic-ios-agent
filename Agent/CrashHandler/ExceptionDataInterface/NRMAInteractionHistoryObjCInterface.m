//
//  NRMAInteractionHistoryObjCInterface.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAInteractionHistoryObjCInterface.h"
#import "NRMAInteractionHistory.h"
@implementation NRMAInteractionHistoryObjCInterface


// The C layer synchronizes its own writers and needs no lock to be read, so
// this lock no longer protects the history itself. It is kept only to preserve
// the ordering callers have always observed between an insert and a clear.
static const NSString* kNRMAIteractionLock = @"interactionLock";
+ (void) insertInteraction:(NSString*)name startTime:(long long)epochMillis
{
    @synchronized (kNRMAIteractionLock){
        NRMA__AddInteraction(name.UTF8String, epochMillis);
    }
}

+ (void) deallocInteractionHistory
{
    @synchronized(kNRMAIteractionLock) {
        NRMA__clearInteractionHistory();
    }
}
@end
