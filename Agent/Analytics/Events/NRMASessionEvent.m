//
//  NRMASessionEvent.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import "NRMASessionEvent.h"
#import "Constants.h"

@implementation NRMASessionEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                  category:(NSString *) category
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds withAttributeValidator:attributeValidator];
    if (self) {
        self.category = category;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[kNRMA_RA_category] = self.category;
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.category forKey:@"Category"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        self.category = [coder decodeObjectForKey:@"Category"];
    }
    
    return self;
}

@end
