//
//  NRMAPersistentRetryTracker.m
//  NewRelic
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAPersistentRetryTracker.h"
#import "NRLogger.h"

// Name of the counter plist, written into each report's own directory.
static NSString* const kNRMAHexRetryCountsFile = @"NRHexRetryCounts.plist";

@interface NRMAPersistentRetryTracker ()
@property(assign) NSUInteger retryLimit;
// directory path -> (report filename -> attempt count). In-memory mirror of the
// on-disk plists, loaded lazily per directory. Guarded by @synchronized(self).
@property(strong) NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSNumber*>*>* countsByDir;
@end

@implementation NRMAPersistentRetryTracker

- (instancetype) initWithRetryLimit:(NSUInteger)retryLimit {
    self = [super init];
    if (self) {
        _retryLimit = retryLimit;
        _countsByDir = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL) recordAttemptAndShouldDrop:(NSString*)reportId {
    NSString* dir = nil, *name = nil;
    if (![self splitReportId:reportId dir:&dir name:&name]) {
        return NO; // unusable id — never drop on our account
    }
    @synchronized (self) {
        NSMutableDictionary<NSString*, NSNumber*>* counts = [self countsForDirectory:dir];
        NSUInteger attempts = [counts[name] unsignedIntegerValue] + 1;
        counts[name] = @(attempts);
        [self persistCountsForDirectory:dir];
        BOOL shouldDrop = attempts > self.retryLimit;
        NRLOG_AGENT_VERBOSE(@"[HexDelete] persistent retry: report %@ attempt %lu/%lu -> %@",
                            name, (unsigned long)attempts, (unsigned long)self.retryLimit,
                            shouldDrop ? @"DROP" : @"retry");
        return shouldDrop;
    }
}

- (void) clearReportId:(NSString*)reportId {
    NSString* dir = nil, *name = nil;
    if (![self splitReportId:reportId dir:&dir name:&name]) {
        return;
    }
    @synchronized (self) {
        NSMutableDictionary<NSString*, NSNumber*>* counts = [self countsForDirectory:dir];
        if (counts[name] != nil) {
            [counts removeObjectForKey:name];
            [self persistCountsForDirectory:dir];
            NRLOG_AGENT_VERBOSE(@"[HexDelete] persistent retry: cleared counter for report %@", name);
        }
    }
}

#pragma mark - helpers (call with @synchronized(self) held)

// Splits a full report path into its directory and filename. Returns NO if either
// piece is empty (nil/empty id, or a bare filename with no directory).
- (BOOL) splitReportId:(NSString*)reportId dir:(NSString**)outDir name:(NSString**)outName {
    if (reportId.length == 0) return NO;
    NSString* dir = [reportId stringByDeletingLastPathComponent];
    NSString* name = [reportId lastPathComponent];
    if (dir.length == 0 || name.length == 0) return NO;
    if (outDir) *outDir = dir;
    if (outName) *outName = name;
    return YES;
}

- (NSString*) plistPathForDirectory:(NSString*)dir {
    return [dir stringByAppendingPathComponent:kNRMAHexRetryCountsFile];
}

// Loads (once) the counts for a directory, pruning entries whose report file no longer
// exists so the plist cannot grow without bound as reports come and go.
- (NSMutableDictionary<NSString*, NSNumber*>*) countsForDirectory:(NSString*)dir {
    NSMutableDictionary<NSString*, NSNumber*>* cached = self.countsByDir[dir];
    if (cached != nil) return cached;

    NSMutableDictionary<NSString*, NSNumber*>* counts = [NSMutableDictionary new];
    NSDictionary* onDisk = [NSDictionary dictionaryWithContentsOfFile:[self plistPathForDirectory:dir]];
    NSFileManager* fm = [NSFileManager defaultManager];
    for (NSString* name in onDisk) {
        if (![name isKindOfClass:[NSString class]]) continue;
        NSNumber* count = onDisk[name];
        if (![count isKindOfClass:[NSNumber class]]) continue;
        // Drop stale counters for reports that are no longer on disk.
        if ([fm fileExistsAtPath:[dir stringByAppendingPathComponent:name]]) {
            counts[name] = count;
        }
    }
    self.countsByDir[dir] = counts;
    return counts;
}

- (void) persistCountsForDirectory:(NSString*)dir {
    NSString* plistPath = [self plistPathForDirectory:dir];
    NSMutableDictionary<NSString*, NSNumber*>* counts = self.countsByDir[dir];
    if (counts.count == 0) {
        // Nothing to track — don't leave an empty plist lying around.
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
        return;
    }
    NSError* error = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:counts
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&error];
    if (data == nil || ![data writeToFile:plistPath atomically:YES]) {
        NRLOG_AGENT_WARNING(@"[HexDelete] persistent retry: failed to persist counts to %@: %@",
                            plistPath, error ? error.localizedDescription : @"write failed");
    }
}

@end
