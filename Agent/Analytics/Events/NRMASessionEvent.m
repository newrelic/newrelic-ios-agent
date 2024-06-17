//
//  NRMASessionEvent.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import "NRMASessionEvent.h"
#import "Constants.h"

static NSString* const kCategoryKey = @"Category";

@implementation NRMASessionEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

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
    
    [coder encodeObject:self.category forKey:kCategoryKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        self.category = [coder decodeObjectOfClass:[NSString class] forKey:kCategoryKey];
    }
    
    return self;
}

@end
