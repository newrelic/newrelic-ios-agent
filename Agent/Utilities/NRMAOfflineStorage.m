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

@implementation NRMAOfflineStorage {
}
static NSString* _name;


- (id)initWithEndpoint:(NSString*) name {
    self = [super init];
    if (self) {
        _name = name;
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
        
        NSError *error = nil;
        if (data) {
            if ([data writeToFile:[self newOfflineFilePath] options:NSDataWritingAtomic error:&error]) {
                NRLOG_VERBOSE(@"Successfully persisted failed upload data to disk for offline storage.");
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
    return [[NSFileManager defaultManager] removeItemAtPath:[self offlineDirectoryPath] error:NULL];
}

- (NSString*)offlineDirectoryPath {
    return [NSString stringWithFormat:@"%@/%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Offline_file,_name];
}

- (NSString*)newOfflineFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@/%@%@",[self offlineDirectoryPath],date,@".txt"];
}

+ (BOOL)checkErrorToPersist:(NSError*) error {
    return (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotFindHost || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorCannotConnectToHost);
}

@end
