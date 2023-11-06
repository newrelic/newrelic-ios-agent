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
@property (nonatomic, strong) dispatch_queue_t writeQueue;
@property (nonatomic, strong, nullable) dispatch_source_t writeTimer;
@end

@implementation PersistentEventStore {
    NSMutableDictionary *store;
    NSString *_filename;
    NSTimeInterval _minimumDelay;
    NSDate *_lastSave;
    
    dispatch_queue_t _writeQueue;
    dispatch_source_t _writeTimer;
}

- (nonnull instancetype)initWithFilename:(NSString *)filename
                         andMinimumDelay:(NSTimeInterval)minimumDelay {
    self = [super init];
    if (self) {
        store = [NSMutableDictionary new];
        _filename = filename;
        _minimumDelay = minimumDelay;
        _lastSave = [NSDate new];
        
        _writeQueue = dispatch_queue_create("com.newrelic.persistentce", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    store[key] = object;
    
    // Check if we're already in a write delay
    if(self.writeTimer) {
        return;
    }
    
    self.writeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _writeQueue);
    dispatch_source_set_timer(self.writeTimer, dispatch_walltime(NULL, 0), _minimumDelay * NSEC_PER_SEC, 100);
    
    __weak __typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.writeTimer, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf saveToFile];
        
        dispatch_source_cancel(strongSelf.writeTimer);
        strongSelf.writeTimer = nil;
    });
    
    dispatch_resume(self.writeTimer);
}

- (void)removeObjectForKey:(id)key {
    [store removeObjectForKey:key];
    
    __weak __typeof(self) weakSelf = self;
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf saveToFile];
        
        if(strongSelf.writeTimer) {
            dispatch_source_cancel(strongSelf.writeTimer);
            strongSelf.writeTimer = nil;
        }
    });
}

- (nullable id)objectForKey:(nonnull id)key {
    return store[key];
}

- (void)clearAll {
    [store removeAllObjects];
    
    __weak __typeof(self) weakSelf = self;
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf saveToFile];

        if(strongSelf.writeTimer) {
            dispatch_source_cancel(strongSelf.writeTimer);
            strongSelf.writeTimer = nil;
        }
    });
}

- (BOOL)load:(NSError **)error {
    NSData *storedData = [NSData dataWithContentsOfFile:_filename
                                                options:0
                                                  error:&error];
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
    
    [store addEntriesFromDictionary:storedDictionary];
    return YES;
}

- (void)saveToFile {
    NSData *saveData = [NSKeyedArchiver archivedDataWithRootObject:store];
    if (saveData) {
        NSError *error = nil;
        BOOL success = [saveData writeToFile:_filename
                                     options:NSDataWritingAtomic
                                       error:&error];
        if(!success) {
            NSLog(@"Error saving data");
        } else {
            _lastSave = [NSDate new];
        }
    }
}

+ (NSDictionary *)getLastSessionEventsFromFilename:(NSString *)filename {
    NSError * __autoreleasing *error = nil;
    NSData *storedData = [NSData dataWithContentsOfFile:filename
                                                options:0
                                                  error:error];
    if(storedData == nil) {
        if(error != NULL && *error != nil) {
            return @{};
        }
    }
    
    NSDictionary *storedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:storedData
                                                                                  error:error];
    if(storedDictionary == nil) {
        if(error != NULL && *error != nil) {
            return @{};
        }
    }

    return storedDictionary;
}

@end
