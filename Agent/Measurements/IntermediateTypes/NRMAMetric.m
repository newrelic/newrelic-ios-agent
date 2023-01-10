//
//  NRMAMetric.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMetric.h"
#import "NRMATraceController.h"
@implementation NRMAMetric

- (instancetype) initWithName:(NSString*)name
              value:(NSNumber*)value
              scope:(NSString*)scope
    produceUnscoped:(BOOL)produceUnscoped
    additionalValue:(NSNumber* __nullable)additionalValue

{
    self = [super init];
    if (self) {
        self.name = name;
        self.value = value;
        self.scope = scope;
        self.produceUnscopedMetrics = produceUnscoped;
        self.additionalValue = additionalValue;
    }
    return self;
}

- (instancetype) initWithName:(NSString*)name
                        value:(NSNumber*)value
                        scope:(NSString*)scope
{
    return [self initWithName:name
                        value:value
                        scope:scope
              produceUnscoped:YES
              additionalValue:nil];
}

- (instancetype) initWithName:(NSString*)name
                        value:(NSNumber*)value
              additionalValue:(NSNumber*)additionalValue
                        scope:(NSString*)scope
{
    return [self initWithName:name
                        value:value
                        scope:scope
              produceUnscoped:YES
              additionalValue:additionalValue];
}

@end
