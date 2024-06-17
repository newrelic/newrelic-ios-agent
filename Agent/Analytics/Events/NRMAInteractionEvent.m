//
//  NRMAInteractionEvent.m
//  Agent
//
//  Created by Mike Bruin on 8/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAInteractionEvent.h"
#import "Constants.h"

static NSString* const kCategoryKey = @"Category";
static NSString* const kNameKey = @"Name";

@implementation NRMAInteractionEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

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

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.category forKey:kCategoryKey];
    [coder encodeObject:self.name forKey:kNameKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        self.category = [coder decodeObjectOfClass:[NSString class] forKey:kCategoryKey];
        self.name = [coder decodeObjectOfClass:[NSString class] forKey:kNameKey];
    }
    
    return self;
}

@end
