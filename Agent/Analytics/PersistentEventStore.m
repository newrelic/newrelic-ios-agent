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
@property (strong, nonatomic) dispatch_block_t pendingBlock;
@end

@implementation PersistentEventStore {
    NSMutableDictionary *store;
    NSString *_filename;
    NSTimeInterval _minimumDelay;
    NSDate *_lastSave;
    BOOL _dirty;
    
    dispatch_queue_t _writeQueue;
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

- (void)performWrite:(void (^)(void))writeBlock {
    dispatch_async(self.writeQueue, ^{
        if (self.pendingBlock != nil) {
            dispatch_block_cancel(self.pendingBlock);
        }
        
        self.pendingBlock = dispatch_block_create(0, writeBlock);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self->_minimumDelay * NSEC_PER_SEC)), self->_writeQueue, self.pendingBlock);
    });
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    @synchronized (store) {
        store[key] = object;
        _dirty = YES;
       // NRLOG_AUDIT(@"Marked dirty for adding");
    }
    
   // NRLOG_AUDIT(@"Scheduling block");
    [self performWrite: ^ {
       // NRLOG_AUDIT(@"Entered block");
        @synchronized (self) {
            if(!self->_dirty) {
                NRLOG_AUDIT(@"Not writing file because it's not dirty");
                return;
            }
        }
        [self saveToFile];
        self->_dirty = NO;
    }];
}

- (void)removeObjectForKey:(id)key {
    @synchronized (store) {
        [store removeObjectForKey:key];
        _dirty = YES;
       // NRLOG_VERBOSE(@"Marked dirty for removing");
    }
    
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
       // NRLOG_VERBOSE(@"Entered Remove Block");
        @synchronized (self) {
            if(!self->_dirty) {
                NRLOG_VERBOSE(@"Not writing removed item file because it's not dirty");
                return;
            }
        }
        [self saveToFile];
        self->_dirty = NO;
    });
}

- (nullable id)objectForKey:(nonnull id)key {
    return store[key];
}

- (void)clearAll {
    @synchronized (store) {
        [store removeAllObjects];
        _dirty = YES;
       // NRLOG_VERBOSE(@"Marked dirty for clearing");
    }
    
    dispatch_after(DISPATCH_TIME_NOW, self.writeQueue, ^{
       // NRLOG_VERBOSE(@"Entered Clear Block");
        @synchronized (self) {
            if(!self->_dirty) {
              //  NRLOG_VERBOSE(@"Not writing cleared file because it's not dirty");
                return;
            }
        }
        [self saveToFile];
        self->_dirty = NO;
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
        if (@available(iOS 11.0, *)) {
            saveData = [NSKeyedArchiver archivedDataWithRootObject:store
                                             requiringSecureCoding:NO
                                                             error:&error];
        } else {
            // Fallback on earlier versions
            saveData = [NSKeyedArchiver archivedDataWithRootObject:store];
        }
    }

    if (saveData) {
        BOOL success = [saveData writeToFile:_filename
                                     options:NSDataWritingAtomic
                                       error:&error];
        if(!success) {
            NRLOG_ERROR(@"Error saving data: %@", error.description);
        } else {
           // NRLOG_AUDIT(@"Wrote file");
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
