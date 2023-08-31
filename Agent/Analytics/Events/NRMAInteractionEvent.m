//
//  NRMAInteractionEvent.m
//  Agent
//
//  Created by Mike Bruin on 8/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAInteractionEvent.h"
#import "Constants.h"

@implementation NRMAInteractionEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                      name:(NSString *) name
                                  category:(NSString *) category
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds withAttributeValidator:attributeValidator];
    if (self) {
        self.category = category;
        self.name = name;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[kNRMA_RA_category] = self.category;
    dict[kNRMA_Attrib_name] = self.name;

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
