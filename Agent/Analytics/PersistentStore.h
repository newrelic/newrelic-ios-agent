//
//  PersistentStore.h
//  Agent
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PersistentStore<KeyType, ObjectType> : NSObject

- (instancetype)initWithFilename:(NSString *)filename;
- (void)setObject:(ObjectType)object forKey:(KeyType)key;
- (nullable ObjectType)objectForKey:(KeyType)key;
- (BOOL)load;

@end

NS_ASSUME_NONNULL_END
