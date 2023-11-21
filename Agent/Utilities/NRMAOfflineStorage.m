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
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage offlineDirectoryPath] isDirectory:nil];
    if(!fileExists){
        NSError *error = nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[NRMAOfflineStorage offlineDirectoryPath] withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create directory \"%@\". Error: %@", [NRMAOfflineStorage offlineDirectoryPath], error);
        }
    }
}

- (BOOL) persistDataToDisk:(NSData*) data {
    @synchronized (_name) {
        [self createDirectory];
        
        NSError *error = nil;
        if (data) {
            if ([data writeToFile:[NRMAOfflineStorage newOfflineFilePath] options:NSDataWritingAtomic error:&error]) {
                return YES;
            }
        }
        NRLOG_ERROR(@"Failed to persist data to disk %@", error.description);
        
        return NO;
    }
}

- (NSArray<NSData *> *) getAllOfflineData {
    @synchronized (_name) {
        NSMutableArray<NSData *> *combinedPosts = [NSMutableArray array];
        
        NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NRMAOfflineStorage offlineDirectoryPath]
                                                                            error:NULL];
        [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *filename = (NSString *)obj;
            NSData * data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",[NRMAOfflineStorage offlineDirectoryPath],filename]];
            
            [combinedPosts addObject:data];
        }];
        
        [self clearAll];
        
        return [combinedPosts copy];
    }
}

- (BOOL) clearAll {
    return [[NSFileManager defaultManager] removeItemAtPath:[NRMAOfflineStorage offlineDirectoryPath] error:NULL];
}

/*- (NSArray<NSDictionary *> *) getAllOfflineData {
    NSMutableArray<NSDictionary *> *combinedDictionaries = [NSMutableArray array];
    __block NSMutableDictionary *currentDictionary = [NSMutableDictionary dictionary];
    __block NSUInteger currentSize = 0;
    const NSUInteger maxSize = 1024 * 1024; // 1 MB in bytes
    
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NRMAOfflineStorage offlineDirectoryPath]
                                                                        error:NULL];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
        NSData * data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",[NRMAOfflineStorage offlineDirectoryPath],filename]];
        NSUInteger dictSize = [data length];

        NSArray* arr = [NRMAJSON JSONObjectWithData:data options:0 error:nil];
        
        NSMutableArray* events = [[NSMutableArray alloc]initWithArray: arr[3]];
        NSMutableArray* metrics = [[NSMutableArray alloc]initWithArray: arr[4]];

        if (currentSize + dictSize <= maxSize) {
           // [currentDictionary addEntriesFromDictionary:dict];
            currentSize += dictSize;
        } else {
            [combinedDictionaries addObject:[currentDictionary copy]];
           // currentDictionary = [NSMutableDictionary dictionaryWithDictionary:dict];
            currentSize = dictSize;
        }
    
        if ([currentDictionary count] > 0) {
            [combinedDictionaries addObject:[currentDictionary copy]];
        }
    }];

    return [combinedDictionaries copy];
}*/

+ (NSString*)offlineDirectoryPath {
    return [NSString stringWithFormat:@"%@/%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Offline_file,_name];
}

+ (NSString*)newOfflineFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@/%@%@",[NRMAOfflineStorage offlineDirectoryPath],date,@".txt"];
}

@end
