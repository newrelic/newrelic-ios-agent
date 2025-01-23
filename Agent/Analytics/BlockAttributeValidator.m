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

static BlockAttributeValidator *_attributeValidator;
+ (BlockAttributeValidator *) attributeValidator
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _attributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
            if ([name length] == 0) {
                NRLOG_AGENT_ERROR(@"invalid attribute: name length = 0");
                return false;
            }
            if ([name hasPrefix:@" "]) {
                NRLOG_AGENT_ERROR(@"invalid attribute: name prefix = \" \"");
                return false;
            }
            // check if attribute name is reserved or attribute name matches reserved prefix.
            for (NSString* key in [NRMAAnalytics reservedKeywords]) {
                if ([key isEqualToString:name]) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
                    return false;
                }
            }
            for (NSString* key in [NRMAAnalytics reservedPrefixes]) {
                if ([name hasPrefix:key])  {
                    NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
                    return false;
                }
            }

            // check if attribute name exceeds max length.
            if ([name length] > kNRMA_Attrib_Max_Name_Length) {
                NRLOG_AGENT_ERROR(@"invalid attribute: name length exceeds limit");
                return false;
            }
            return true;
            
        } valueValidator:^BOOL(id value) {
            if ([value isKindOfClass:[NSString class]]) {
                if ([(NSString*)value length] == 0) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: value length = 0");
                    return false;
                }
                else if ([(NSString*)value length] >= kNRMA_Attrib_Max_Value_Size_Bytes) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
                    return false;
                }
            }
            if (value == nil || [value isKindOfClass:[NSNull class]]) {
                NRLOG_AGENT_ERROR(@"invalid attribute: value cannot be nil");
                return false;
            }
            
            return true;
        } andEventTypeValidator:^BOOL(NSString *eventType) {
            return YES;
        }];
    });

    return _attributeValidator;
}

@end
