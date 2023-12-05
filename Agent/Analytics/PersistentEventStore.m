//
//  PersistentStore.m
//  Agent
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "PersistentEventStore.h"
#import "NRLogger.h"

@interface PersistentEventStore ()
@property (strong) NSOperationQueue *workQueue;
@end

@implementation PersistentEventStore {
    NSMutableDictionary *store;
    NSString *_filename;
    NSTimeInterval _minimumDelay;
    NSDate *_lastSave;
    BOOL _dirty;
}

- (nonnull instancetype)initWithFilename:(NSString *)filename
                         andMinimumDelay:(NSTimeInterval)secondsDelay {
    self = [super init];
    if (self) {
        store = [NSMutableDictionary new];
        _filename = filename;
        _minimumDelay = secondsDelay;
        _lastSave = [NSDate new];
        _dirty = NO;
        _workQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)saveFile {
    if ([_lastSave timeIntervalSinceReferenceDate] < _minimumDelay) {
        [NSThread sleepForTimeInterval:_minimumDelay];
    }
    if(!_dirty) {
        NRLOG_VERBOSE(@"Not writing file because it's not dirty");
        return;
    }
    [self saveToFile];
    _dirty = NO;
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    @synchronized (store) {
        store[key] = object;
        _dirty = YES;
        NRLOG_VERBOSE(@"Marked dirty for adding");
    }
    
    __block PersistentEventStore *blockSafeSelf = self;
    if (@available(iOS 13.0, *)) {
        [_workQueue addBarrierBlock:^{
            NRLOG_VERBOSE(@"Entered Add Block");
            [blockSafeSelf saveFile];
        }];
    } else {
        [_workQueue addOperationWithBlock:^{
            NRLOG_VERBOSE(@"Entered Add Block");
            [blockSafeSelf saveFile];
        }];
        [_workQueue waitUntilAllOperationsAreFinished];
    }
}

- (void)removeObjectForKey:(id)key {
    @synchronized (store) {
        [store removeObjectForKey:key];
        _dirty = YES;
        NRLOG_VERBOSE(@"Marked dirty for removing");
    }
    
    __block PersistentEventStore *blockSafeSelf = self;
    if (@available(iOS 13.0, *)) {
        [_workQueue addBarrierBlock:^{
            NRLOG_VERBOSE(@"Entered Remove Block");
            [blockSafeSelf saveFile];
        }];
    } else {
        [_workQueue addOperationWithBlock:^{
            NRLOG_VERBOSE(@"Entered Remove Block");
            [blockSafeSelf saveFile];
        }];
        [_workQueue waitUntilAllOperationsAreFinished];
    }
}

- (nullable id)objectForKey:(nonnull id)key {
    return store[key];
}

- (void)clearAll {
    @synchronized (store) {
        [store removeAllObjects];
        _dirty = YES;
        NRLOG_VERBOSE(@"Marked dirty for clearing");
    }
    __block PersistentEventStore *blockSafeSelf = self;
    if (@available(iOS 13.0, *)) {
        [_workQueue addBarrierBlock:^{
            NRLOG_VERBOSE(@"Entered Clear Block");
            [blockSafeSelf removeFile];
        }];
    } else {
        [_workQueue addOperationWithBlock:^{
            NRLOG_VERBOSE(@"Entered Clear Block");
            [blockSafeSelf removeFile];
        }];
        [_workQueue waitUntilAllOperationsAreFinished];
    }
}

- (void)removeFile {
    @synchronized (self) {
        if(![[NSFileManager defaultManager] fileExistsAtPath:_filename]){
            return;
        }
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath:_filename error:&error];
        if (error) {
            NRLOG_ERROR(@"Failed to clear Persisted data w/ error = %@", error);
        }
        _dirty = NO;
    }
}

- (BOOL)load:(NSError **)error {
    NSData *storedData;
    @synchronized (self) {
        storedData = [NSData dataWithContentsOfFile:_filename
                                                    options:0
                                                      error:&error];
    }
    if(storedData == nil) {
        if(error != NULL && *error != nil) {
            return NO;
        }
    }
    
    NSMutableDictionary *storedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:storedData
                                                                                         error:error];
    if(storedDictionary == nil) {
        if(error != NULL && *error != nil) {
            return NO;
        }
    }
    
    @synchronized (store) {
        [store addEntriesFromDictionary:storedDictionary];
    }
    return YES;
}

- (void)saveToFile {
    NSError *error = nil;
    NSData *saveData = nil;
    @synchronized (store) {
        if (@available(iOS 11.0, *)) {
            saveData = [NSKeyedArchiver archivedDataWithRootObject:store
                                             requiringSecureCoding:NO
                                                             error:&error];
        } else {
            saveData = [NSKeyedArchiver archivedDataWithRootObject:store];
        }
    }
    @synchronized (self) {
        if (saveData) {
            BOOL success = [saveData writeToFile:_filename
                                         options:NSDataWritingAtomic
                                           error:&error];
            if(!success) {
                NRLOG_ERROR(@"Error saving data: %@", error);
            } else {
                NRLOG_VERBOSE(@"Wrote file");
                _lastSave = [NSDate new];
            }
        }
    }
}

- (NSDictionary *)getLastSessionEvents {
    NSData *storedData;
    NSError * __autoreleasing *error = nil;
    @synchronized (self) {
        storedData = [NSData dataWithContentsOfFile:_filename
                                                    options:0
                                                      error:error];
    }
    if(storedData == nil) {
        if(error != NULL && *error != nil) {
            NRLOG_ERROR(@"Error getting last sessions saved events: %@", *error);
            return @{};
        }
    }
    
    NSDictionary *storedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:storedData
                                                                                  error:error];
    if(storedDictionary == nil) {
        if(error != NULL && *error != nil) {
            NRLOG_ERROR(@"Error converting last sessions saved events to dictionary: %@", *error);
            return @{};
        }
    }
    
    return storedDictionary;
}

+ (NSDictionary *)getLastSessionEventsFromFilename:(NSString *)filename {
    NSError * __autoreleasing *error = nil;
    NSData *storedData;
    @synchronized (self) {
        storedData = [NSData dataWithContentsOfFile:filename
                                                    options:0
                                                      error:error];
    }
    if(storedData == nil) {
        if(error != NULL && *error != nil) {
            NRLOG_ERROR(@"Error getting last sessions saved events: %@", *error);
            return @{};
        }
    }
    
    NSDictionary *storedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:storedData
                                                                                  error:error];
    if(storedDictionary == nil) {
        if(error != NULL && *error != nil) {
            NRLOG_ERROR(@"Error converting last sessions saved events to dictionary: %@", *error);
            return @{};
        }
    }
    
    return storedDictionary;
}

@end
