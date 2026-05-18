//
//  NRMAUserActionEvent.m
//  Agent
//
//  Created by Mike Bruin on 1/29/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAUserActionEvent.h"
#import "Constants.h"

static NSString* const kCategoryKey = @"Category";

@implementation NRMAUserActionEvent

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
        self.eventType = kNRMA_RET_mobileUserAction;
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
