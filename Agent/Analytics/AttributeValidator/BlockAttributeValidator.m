//
//  BlockAttributeValidator.m
//  Agent
//
//  Created by Steve Malsam on 6/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "BlockAttributeValidator.h"
#import "Constants.h"
#import "NRMAAnalytics.h"
#import "NRLogger.h"

@implementation BlockAttributeValidator

- (nonnull instancetype)initWithNameValidator:(nonnull NameValidator)nameValidator
                               valueValidator:(nonnull ValueValidator)valueValidator
                        andEventTypeValidator:(nonnull EventTypeValidator)eventTypeValidator {
    self = [super init];
    if(self) {
        _nameValidator = nameValidator;
        _valueValidator = valueValidator;
        _eventTypeValidator = eventTypeValidator;
    }
    
    return self;
}

- (BOOL)eventTypeValidator:(NSString *)eventType {
    return self.eventTypeValidator(eventType);
}

- (BOOL)nameValidator:(NSString *)name {
    return self.nameValidator(name);
}

- (BOOL)valueValidator:(id)value {
    return self.valueValidator(value);
}

@end
