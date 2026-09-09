//
//  NRMAViewEvent.m
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAViewEvent.h"
#import "Constants.h"

static NSString* const kCategoryKey = @"Category";

@implementation NRMAViewEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                  category:(NSString *)category
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp
        sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds
             withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = eventType.length > 0 ? eventType : kNRMA_RET_mobileView;
        self.category  = category.length  > 0 ? category  : kNRMA_RET_mobile;
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
        // A dictionary archived before this class existed, or one whose category failed to
        // decode, must still ship a category -- the whole point of the built-in event is that
        // its shape does not depend on how it reached the harvest.
        if (self.category.length == 0) {
            self.category = kNRMA_RET_mobile;
        }
    }

    return self;
}
@end
