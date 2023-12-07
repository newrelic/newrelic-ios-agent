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
    BOOL _dirty;
    
    dispatch_queue_t _writeQueue;
    dispatch_source_t _writeTimer;
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
        
        _writeQueue = dispatch_queue_create("com.newrelic.persistentce", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    @synchronized (store) {
        store[key] = object;
        _dirty = YES;
        NRLOG_VERBOSE(@"Marked dirty for adding");
    }
    
    @synchronized (self) {
        // If the timer itself is not initialized, or if the timer is cancelled, then we
        // should schedule a write.
        if( (self.writeTimer != nil)
           && (dispatch_source_testcancel(self.writeTimer) == 0)) {
            NRLOG_VERBOSE(@"Not Scheduling block; last wrote at %d", _lastSave);
            return;
        }
        
        NRLOG_VERBOSE(@"Scheduling block");
        self.writeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _writeQueue);
        dispatch_source_set_timer(self.writeTimer, dispatch_time(DISPATCH_TIME_NOW, _minimumDelay * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 100);
        
        NRLOG_VERBOSE(@"Entered block");
        dispatch_source_set_event_handler(self.writeTimer, ^{
            
            @synchronized (self) {
                if(!self->_dirty) {
                    NRLOG_VERBOSE(@"Not writing file because it's not dirty");
                    return;
                }
            }
            
            [self saveToFile];
            self->_dirty = NO;
            
            dispatch_source_cancel(self.writeTimer);
        });
        
        dispatch_resume(self.writeTimer);
    }
}

- (void)removeObjectForKey:(id)key {
    @synchronized (store) {
        [store removeObjectForKey:key];
        _dirty = YES;
        NRLOG_VERBOSE(@"Marked dirty for removing");
    }
    
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
        NRLOG_VERBOSE(@"Entered Remove Block");
        @synchronized (self) {
            if(!self->_dirty) {
                NRLOG_VERBOSE(@"Not writing removed item file because it's not dirty");
                return;
            }
        }
        [self saveToFile];
        self->_dirty = NO;
        
        if(self.writeTimer) {
            dispatch_source_cancel(self.writeTimer);
        }
    });
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
    
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
        NRLOG_VERBOSE(@"Entered Clear Block");
        @synchronized (self) {
            if(!self->_dirty) {
                NRLOG_VERBOSE(@"Not writing cleared file because it's not dirty");
                return;
            }
        }
        [self saveToFile];
        self->_dirty = NO;

        if(self.writeTimer) {
            dispatch_source_cancel(self.writeTimer);
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
    
    @synchronized (store) {
        [store addEntriesFromDictionary:storedDictionary];
    }
    return YES;
}

- (void)saveToFile {
    NSError *error = nil;
    NSData *saveData = nil;
    @synchronized (store) {
        saveData = [NSKeyedArchiver archivedDataWithRootObject:store
                                                 requiringSecureCoding:NO
                                                                 error:&error];
    }

    if (saveData) {
        BOOL success = [saveData writeToFile:_filename
                                     options:NSDataWritingAtomic
                                       error:&error];
        if(!success) {
            NRLOG_VERBOSE(@"Error saving data");
        } else {
            NRLOG_VERBOSE(@"Wrote file");
            _lastSave = [NSDate new];
        }
    }
}

- (NSDictionary *)getLastSessionEvents {
    NSError * __autoreleasing *error = nil;
    NSData *storedData = [NSData dataWithContentsOfFile:_filename
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
