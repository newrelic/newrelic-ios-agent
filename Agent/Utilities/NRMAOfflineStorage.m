//
//  NRMAOfflineStorage.m
//  Agent
//
//  Created by Mike Bruin on 11/17/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewRelicInternalUtils.h"
#import "NRLogger.h"
#import "NRMAOfflineStorage.h"
#import "Constants.h"
#import "NRMAJSON.h"
#import "NRMASupportMetricHelper.h"
#import "NRMAAgentConfiguration.h"

// Default time-to-live for persisted offline payloads: 7 days, in seconds.
// Aligned with the shortest applicable New Relic data-retention window (Session Replay ~8 days).
#define kNRMADefaultOfflineStorageTTLSeconds (7 * 24 * 60 * 60)

// Shared across all endpoints so the TTL can be configured globally, mirroring the
// Android agent's static offlineStorageTTL.
static NSTimeInterval __NRMA__offlineStorageTTLSeconds = kNRMADefaultOfflineStorageTTLSeconds;

@implementation NRMAOfflineStorage {
    NSUInteger maxOfflineStorageSizeBytes;
    NSString* _name;
}

- (id)initWithEndpoint:(NSString*) name {
    self = [super init];
    if (self) {
        _name = name;
        maxOfflineStorageSizeBytes = [NRMAAgentConfiguration getMaxOfflineStorageSize]; // Already in bytes
    }
    return self;
}

- (void) createDirectory {
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil];
    if(!fileExists){
        NSError *error = nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[self offlineDirectoryPath] withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create directory \"%@\". Error: %@", [self offlineDirectoryPath], error);
        }
    }
}

- (BOOL) persistDataToDisk:(NSData*) data {
    @synchronized (self) {
        [self createDirectory];

        NSUInteger currentOfflineStorageSize = [self currentOfflineStorageSize];
        if (currentOfflineStorageSize + data.length > maxOfflineStorageSizeBytes) {
            // Over the cap: evict the oldest payloads (LRU) to make room for the incoming data
            // rather than dropping the current harvest in favor of stale data.
            [self evictOldestFilesToFit:data.length];
            currentOfflineStorageSize = [self currentOfflineStorageSize];
            if (currentOfflineStorageSize + data.length > maxOfflineStorageSizeBytes) {
                NRLOG_AGENT_WARNING(@"Not saving to offline storage because max storage size has been reached.");
                return NO;
            }
        }

        NSError *error = nil;
        if (data) {
            if ([data writeToFile:[self newOfflineFilePath] options:NSDataWritingAtomic error:&error]) {
                NRLOG_AGENT_VERBOSE(@"Successfully persisted failed upload data to disk for offline storage. Current offline storage: %lu", (unsigned long)(currentOfflineStorageSize + data.length));
                return YES;
            }
        }
        NRLOG_AGENT_ERROR(@"Failed to persist data to disk %@", error.description);

        return NO;
    }
}

- (NSArray<NSData *> *) getAllOfflineData:(BOOL) clear {
    @synchronized (self) {
        NSMutableArray<NSData *> *combinedPosts = [NSMutableArray array];

        NSString* directoryPath = [self offlineDirectoryPath];
        NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath
                                                                            error:NULL];
        NSDate* expiryDate = [NSDate dateWithTimeIntervalSinceNow:-[NRMAOfflineStorage offlineStorageTTL]];
        [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *filename = (NSString *)obj;
            NSString *filePath = [NSString stringWithFormat:@"%@/%@",directoryPath,filename];

            // Drop payloads older than the TTL: once past the backend retention window they
            // produce no value when re-uploaded, so delete them instead of replaying forever.
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
            NSDate *modificationDate = attributes[NSFileModificationDate];
            if (modificationDate && [modificationDate compare:expiryDate] == NSOrderedAscending) {
                NRLOG_AGENT_DEBUG(@"Deleting expired offline storage file: %@", filename);
                [self removeOfflineFileAtPath:filePath];
                return;
            }

            NSData * data = [NSData dataWithContentsOfFile:filePath];

            if (data) {
                NRLOG_AGENT_DEBUG(@"Offline storage to be uploaded from %@", filename);
                [combinedPosts addObject:data];
            } else {
                NRLOG_AGENT_DEBUG(@"Failed to read offline storage file: %@", filename);
            }
        }];

        if(clear){
            [self clearAllOfflineFiles];
        }

        return [combinedPosts copy];
    }
}

- (BOOL) clearAllOfflineFiles {
    if(![[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil]){
        return true;
    }
    
    NSError* error;
    if ([[NSFileManager defaultManager] removeItemAtPath:[self offlineDirectoryPath] error:&error]) {
        return true;
    }
    NRLOG_AGENT_ERROR(@"Failed to clear offline storage: %@", error);
    return false;
}

+ (BOOL) clearAllOfflineDirectories {
    if(![[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]){
        return true;
    }
    
    NSError* error;
    if ([[NSFileManager defaultManager] removeItemAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] error:&error]) {
        return true;
    }
    NRLOG_AGENT_ERROR(@"Failed to clear offline storage: %@", error);
    return false;
}

- (NSString*) offlineDirectoryPath {
    return [NSString stringWithFormat:@"%@/%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Offline_folder,_name];
}

+ (NSString*) allOfflineDirectorysPath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Offline_folder];
}

- (NSString*) newOfflineFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@/%@%@",[self offlineDirectoryPath],date,@".txt"];
}

- (void) setMaxOfflineStorageSize:(NSUInteger) megabytes {
    maxOfflineStorageSizeBytes = megabytes * 1000000; // Convert MB to bytes (1 MB = 1,000,000 bytes)
}

// Computes this store's current on-disk size (in bytes) by summing the sizes of the files
// in its own offline directory. Computed on demand rather than cached in a shared counter:
// a cached total drifts when same-second filename collisions overwrite files, and a counter
// shared across stores is corrupted when one store's clear zeroes the other's accounting.
// Reading the directory keeps the size correct from both angles and per-store isolated.
- (NSUInteger) currentOfflineStorageSize {
    NSString* directoryPath = [self offlineDirectoryPath];
    NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:NULL];
    NSUInteger totalSize = 0;
    for (NSString* filename in filenames) {
        NSString* filePath = [NSString stringWithFormat:@"%@/%@", directoryPath, filename];
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
        if (attributes) {
            totalSize += [attributes[NSFileSize] unsignedIntegerValue];
        }
    }
    return totalSize;
}

// Evicts the oldest persisted payloads (least-recently-modified first) until the incoming
// data of length incomingDataLength would fit under the max storage size, or until there
// is nothing left to evict.
- (void) evictOldestFilesToFit:(NSUInteger) incomingDataLength {
    NSString* directoryPath = [self offlineDirectoryPath];
    NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:NULL];
    if (filenames.count == 0) {
        return;
    }

    // Collect each file's path, modification date and size, then sort oldest first.
    NSMutableArray<NSDictionary*>* fileInfos = [NSMutableArray array];
    for (NSString* filename in filenames) {
        NSString* filePath = [NSString stringWithFormat:@"%@/%@", directoryPath, filename];
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
        if (!attributes) {
            continue;
        }
        [fileInfos addObject:@{@"path" : filePath,
                               @"date" : attributes[NSFileModificationDate] ?: [NSDate distantPast],
                               @"size" : @([attributes[NSFileSize] unsignedIntegerValue])}];
    }
    [fileInfos sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [a[@"date"] compare:b[@"date"]];
    }];

    // Track the running size locally as we delete, subtracting each evicted file's size, to
    // avoid re-scanning the whole directory on every iteration.
    NSUInteger currentOfflineStorageSize = [self currentOfflineStorageSize];
    for (NSDictionary* info in fileInfos) {
        if (currentOfflineStorageSize + incomingDataLength <= maxOfflineStorageSizeBytes) {
            break;
        }
        NRLOG_AGENT_VERBOSE(@"Evicting oldest offline storage file to make room: %@", info[@"path"]);
        NSUInteger size = [info[@"size"] unsignedIntegerValue];
        [self removeOfflineFileAtPath:info[@"path"]];
        currentOfflineStorageSize = (currentOfflineStorageSize > size) ? (currentOfflineStorageSize - size) : 0;
    }
}

// Removes a single offline file from disk.
- (void) removeOfflineFileAtPath:(NSString*) filePath {
    NSError* error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
        NRLOG_AGENT_ERROR(@"Failed to remove offline storage file %@: %@", filePath, error.description);
    }
}

+ (NSTimeInterval) defaultOfflineStorageTTL {
    return kNRMADefaultOfflineStorageTTLSeconds;
}

+ (NSTimeInterval) offlineStorageTTL {
    return __NRMA__offlineStorageTTLSeconds;
}

+ (void) setOfflineStorageTTL:(NSTimeInterval) seconds {
    __NRMA__offlineStorageTTLSeconds = seconds;
}

+ (BOOL)checkErrorToPersist:(NSError*) error {
    return (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotFindHost || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorCannotConnectToHost);
}

@end
