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

#define kNRMAOfflineStorageCurrentSizeKey @"com.newrelic.offlineStorageCurrentSize"

@implementation NRMAOfflineStorage {
    NSUInteger maxOfflineStorageSize;
}
static NSString* _name;

- (id)initWithEndpoint:(NSString*) name {
    self = [super init];
    if (self) {
        _name = name;
        maxOfflineStorageSize = [NRMAAgentConfiguration getMaxOfflineStorageSize];
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
        
        NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:kNRMAOfflineStorageCurrentSizeKey];
        currentOfflineStorageSize += data.length;
        if(currentOfflineStorageSize > maxOfflineStorageSize){
            NRLOG_WARNING(@"Not saving to offline storage because max storage size has been reached.");
            return NO;
        }
        
        NSError *error = nil;
        if (data) {
            if ([data writeToFile:[self newOfflineFilePath] options:NSDataWritingAtomic error:&error]) {
                [[NSUserDefaults standardUserDefaults] setInteger:currentOfflineStorageSize forKey:kNRMAOfflineStorageCurrentSizeKey]; // If we successfully save the data save the new current total size
                NRLOG_VERBOSE(@"Successfully persisted failed upload data to disk for offline storage. Current offline storage: %lu", (unsigned long)currentOfflineStorageSize);
                return YES;
            }
        }
        NRLOG_ERROR(@"Failed to persist data to disk %@", error.description);
        
        return NO;
    }
}

- (NSArray<NSData *> *) getAllOfflineData:(BOOL) clear {
    @synchronized (self) {
        NSMutableArray<NSData *> *combinedPosts = [NSMutableArray array];
        
        NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self offlineDirectoryPath]
                                                                            error:NULL];
        [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *filename = (NSString *)obj;
            NSData * data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",[self offlineDirectoryPath],filename]];
            NRLOG_VERBOSE(@"Offline storage to be uploaded from %@", filename);
            
            [combinedPosts addObject:data];
        }];
        
        if(clear){
            [self clearAllOfflineFiles];
        }
        
        return [combinedPosts copy];
    }
}

- (BOOL) clearAllOfflineFiles {
    NSError* error;
    if ([[NSFileManager defaultManager] removeItemAtPath:[self offlineDirectoryPath] error:&error]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kNRMAOfflineStorageCurrentSizeKey];
        return true;
    }
    NRLOG_ERROR(@"Failed to clear offline storage: %@", error);
    return false;
}

- (NSString*) offlineDirectoryPath {
    return [NSString stringWithFormat:@"%@/%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Offline_folder,_name];
}

- (NSString*) newOfflineFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@/%@%@",[self offlineDirectoryPath],date,@".txt"];
}

- (void) setMaxOfflineStorageSize:(NSUInteger) size {
    maxOfflineStorageSize = (size * 1000000);
}

+ (BOOL)checkErrorToPersist:(NSError*) error {
    return (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotFindHost || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorCannotConnectToHost);
}

@end
