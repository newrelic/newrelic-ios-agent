//
//  PersistentStore.m
//  Agent
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "PersistentEventStore.h"

#import "NRLogger.h"

@implementation PersistentEventStore {
    NSMutableDictionary *store;
    NSString *_filename;
    NSTimeInterval _minimumDelay;
    NSDate *_lastSave;
}

- (nonnull instancetype)initWithFilename:(NSString *)filename
                         andMinimumDelay:(NSTimeInterval)minimumDelay {
    self = [super init];
    if (self) {
        store = [NSMutableDictionary new];
        _filename = filename;
        _minimumDelay = minimumDelay;
        _lastSave = [NSDate new];
    }
    return self;
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    store[key] = object;
    
//    NSTimeInterval delay = [[NSDate new] timeIntervalSinceDate:_lastSave] > _minimumDelay ? 0: _minimumDelay;
//    if(delay == 0) {
        [self saveToFile];
//    }
}

- (void)removeObjectForKey:(id)key {
    [store removeObjectForKey:key];
    [self saveToFile];
}

- (nullable id)objectForKey:(nonnull id)key {
    return store[key];
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

@end
