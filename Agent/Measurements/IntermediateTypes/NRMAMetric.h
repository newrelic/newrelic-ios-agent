//
//  NRMAMetric.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAMetric : NSObject
@property(strong) NSString* name;
@property(strong) NSNumber* value;
@property(strong) NSString* scope;
@property(strong) NSNumber* additionalValue;

@property(assign) BOOL produceUnscopedMetrics;

- (instancetype) initWithName:(NSString*)name
                        value:(NSNumber*)value
                        scope:(NSString* __nullable)scope
              produceUnscoped:(BOOL)produceUnscoped
               additionalValue:(NSNumber* __nullable)additionalValue;
            

- (instancetype) initWithName:(NSString*)name
                        value:(NSNumber*)value
                        scope:(NSString* __nullable)scope;
@end

NS_ASSUME_NONNULL_END
