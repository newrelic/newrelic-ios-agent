//
//  NRMAPersistentRetryTracker.h
//  NewRelic
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Tracks upload retry attempts for PERSISTED handled-exception reports across app
 * launches. Unlike NRMARetryTracker (in memory, keyed by NSURLRequest, reset every
 * launch), this persists a small plist alongside the reports so a report that keeps
 * failing to upload is eventually dropped rather than retried indefinitely on every
 * launch.
 *
 * Reports are keyed by their filename (the last path component of the on-disk report
 * path), which is a unique, timestamped, stable-per-report identifier. The counter
 * plist is stored in the report's own directory, so it is naturally scoped to the hex
 * store and is not enumerated by HexStore::readAll (which only reads ".fbad" files).
 *
 * All methods are thread-safe.
 */
@interface NRMAPersistentRetryTracker : NSObject

- (instancetype) initWithRetryLimit:(NSUInteger)retryLimit;

/*
 * Records one failed server attempt for the report at `reportId` (its on-disk path)
 * and returns YES if the accumulated cross-launch attempt count has EXCEEDED the limit
 * (the caller should give up and drop the report), or NO if it may still be retried.
 * A nil/empty `reportId` returns NO (never drop).
 */
- (BOOL) recordAttemptAndShouldDrop:(nullable NSString*)reportId;

/*
 * Clears the persisted counter for `reportId` — call on a confirmed upload or when the
 * report is dropped. A nil/empty `reportId` is a no-op.
 */
- (void) clearReportId:(nullable NSString*)reportId;

@end

NS_ASSUME_NONNULL_END
