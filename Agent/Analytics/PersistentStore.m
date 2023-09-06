//
//  PersistentStore.m
//  Agent
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "PersistentStore.h"

@implementation PersistentStore {
    NSMutableDictionary *store;
    NSString *_filename;
}

- (nonnull instancetype)initWithFilename:(NSString *)filename {
    self = [super init];
    if (self) {
        store = [NSMutableDictionary new];
        _filename = filename;
    }
    return self;
}

- (void)setObject:(nonnull id)object forKey:(nonnull id)key {
    store[key] = object;
    [self saveToFile];
}

- (nullable id)objectForKey:(nonnull id)key {
    return store[key];
}

- (BOOL)load {
    NSData *storedData = [NSData dataWithContentsOfFile:_filename];
    NSError *error = nil;
    
    NSMutableDictionary *storedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:storedData
                                                                                         error:&error];
    if(error != nil) {
        return NO;
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
        }
        
    }
}

@end
