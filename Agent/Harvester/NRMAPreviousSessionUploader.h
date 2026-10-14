//
//  NRMAPreviousSessionUploader.h
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvesterConnection.h"
#import "NRMADataToken.h"

// Holds the previous session's persisted analytics (the same events/attributes
// JSON the crash reporter reads at launch) and sends them to the /data endpoint
// once, the first time the harvester becomes connected.
//
// The data is captured a single time at launch by
// NRMAExceptionHandlerStartupManager (see -fetchLastSessionsAnalytics) and
// handed here, so the old (C++) event system's duplication store — which is
// cleared on read — is not consumed twice.
@interface NRMAPreviousSessionUploader : NSObject

+ (instancetype) sharedInstance;

// Captures the previous session's analytics JSON. Safe to call with nil/empty
// strings (the upload becomes a no-op). fileModificationDate is the on-disk
// store's modification date at the time it was read (see
// +[NRMAAnalytics getLastSessionEventsFileModificationDate]) -- if it's older
// than the 7-day retention cap, the whole batch is treated as stale and the
// upload is skipped, on the assumption that an abandoned batch is uniformly
// old rather than a mix of ages.
- (void) setLastSessionAttributeJSON:(NSString*)attributeJSON
                           eventJSON:(NSString*)eventJSON
                fileModificationDate:(NSDate*)fileModificationDate;

// Sends the captured analytics as a dedicated harvest using the supplied,
// already-connected connection and data token. Idempotent: only the first call
// per launch performs work.
- (void) uploadWithConnection:(NRMAHarvesterConnection*)connection
                    dataToken:(NRMADataToken*)dataToken;

@end
