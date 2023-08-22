//
//  NRMASAM.mm
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMASAM.h"
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRMABool.h"
#import "AttributeValidatorProtocol.h"
#import "Constants.h"

@implementation NRMASAM {
    NSMutableDictionary<NSString*, id> *attributeDict;
    NSMutableDictionary<NSString*, id> *privateAttributeDict;

    __nullable id<AttributeValidatorProtocol> attributeValidator;
}

- (id)initWithAttributeValidator:(__nullable id<AttributeValidatorProtocol>)validator {
    self = [super init];
    if (self) {

        // Load public attributes from file.
        NSError *error;
        NSData *existingData = [[NRMASAM attributeFilePath] dataUsingEncoding:NSUTF8StringEncoding];
        if (existingData != nil) {
            attributeDict = [[NSJSONSerialization JSONObjectWithData:existingData options:kNilOptions error:&error] mutableCopy];

            if (error == nil) {
                NRLOG_VERBOSE(@"Loaded %lu public attributes from file.", (unsigned long)attributeDict.count);
            }
            else {
                NRLOG_ERROR(@"Error loading public attributes from file: %@", error);
            }
        }
        if (!attributeDict) {
            attributeDict = [[NSMutableDictionary alloc] init];
        }

        // Load private attributes from file.
        NSData *existingPrivateData = [[NRMASAM privateAttributeFilePath] dataUsingEncoding:NSUTF8StringEncoding];
        if (existingPrivateData != nil) {
            privateAttributeDict = [[NSJSONSerialization JSONObjectWithData:existingPrivateData options:kNilOptions error:&error] mutableCopy];

            if (error == nil) {
                NRLOG_VERBOSE(@"Loaded %lu private attributes from file.", (unsigned long)privateAttributeDict.count);
            }
            else {
                NRLOG_ERROR(@"Error loading private attributes from file: %@", error);
            }
        }
        if (!privateAttributeDict) {
            privateAttributeDict = [[NSMutableDictionary alloc] init];
        }

        attributeValidator = validator;
    }
    return self;
}

- (BOOL) setLastInteraction:(NSString*)name {
    return [self setNRSessionAttribute:kNRMA_RA_lastInteraction value:name];
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    @synchronized (privateAttributeDict) {
        [privateAttributeDict setValue:value forKey:name];

        [self persistPrivateAttributesToDisk];
    }
    return YES;
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value];
}

-  (BOOL) setAttribute:(NSString*)name value:(id)value {
    BOOL validAttribute = [attributeValidator nameValidator:name];
    BOOL validValue = [attributeValidator valueValidator:value];

    if (!(validAttribute && validValue)) {
        NRLOG_VERBOSE(@"Failed to create attribute named %@", name);
        return NO;
    }
    if (attributeDict.count >= kNRMA_Attrib_Max_Number_Attributes) {
        NRLOG_VERBOSE(@"Unable to add attribute %@, the max attribute limit (128) is reached", name);
        return NO;
    }

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    @synchronized (attributeDict) {
        [attributeDict setValue:value forKey:name];
        [self persistToDisk];
    }

    return YES;
}

- (BOOL) setUserId:(NSString *)userId {
    return [self setSessionAttribute:kNRMA_Attrib_userId value:userId];
}

- (BOOL) removeSessionAttributeNamed:(NSString*)name {
    @synchronized (attributeDict) {
        id value = [attributeDict objectForKey:name];

        if (value) {
            [attributeDict removeObjectForKey:name];
            [self persistToDisk];
            return YES;
        }
        else {
            NRLOG_VERBOSE(@"Failed to remove Session Attribute - it does not exist.");

            return NO;
        }
    }
}

- (BOOL) removeAllSessionAttributes {
    @synchronized (attributeDict) {
        [attributeDict removeAllObjects];
        [self persistToDisk];
    }
    return YES;
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number {
    id existingValue = [attributeDict objectForKey:name];

    NSNumber *newValue;

    // if the existing value doesn't exist, the user meant to call setAttribute.
    // Should this return NO, to indicate the attribute doesn't exist?
    if (!existingValue) {
        return [self setAttribute:name value:number];
    }

    // cannot increment with non number values
    if (![NewRelicInternalUtils isInteger:number] && ![NewRelicInternalUtils isFloat:number]) {
        return NO;
    }

    // Cannot increment a non-number attribute
    if (![existingValue isKindOfClass:[NSNumber class]] ||
        (![NewRelicInternalUtils isInteger:existingValue] && ![NewRelicInternalUtils isFloat:existingValue])) {
        return NO;
    }

    if ([NewRelicInternalUtils isInteger:existingValue]) {
        unsigned long long incrementValueLongLong = [number unsignedLongLongValue];
        newValue = [NSNumber numberWithUnsignedLongLong:[existingValue unsignedLongLongValue] + incrementValueLongLong];
    } else if ([NewRelicInternalUtils isFloat:existingValue]) {
        double incrementValueDouble = [number doubleValue];
        newValue = [NSNumber numberWithDouble:[existingValue doubleValue] + incrementValueDouble];
    } else {
        // something that's not an integer or a floating point number got through
        return NO;
    }

    @synchronized (attributeDict) {
        [attributeDict setValue:newValue forKey:name];
        [self persistToDisk];
    }

    return YES;
}

// Includes Public and Private Attributes
- (NSString*) sessionAttributeJSONString {

    NSMutableDictionary *output = [attributeDict mutableCopy];
    [output addEntriesFromDictionary:privateAttributeDict];

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:output options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        return( [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    }
    return nil;
}

// Public Attributes Only
- (NSString*) publicSessionAttributeJSONString {

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attributeDict options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        return( [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    }
    return nil;
}

// Private Attributes Only
- (NSString*) privateSessionAttributeJSONString {

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:privateAttributeDict options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        return( [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    }
    return nil;
}

+ (NSString*) getLastSessionsAttributes {
    NSData *data = [NSData dataWithContentsOfFile:[self attributeFilePath]];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void) clearLastSessionsAnalytics {
    @synchronized (attributeDict) {
        @synchronized (privateAttributeDict) {
            [attributeDict removeAllObjects];
            [privateAttributeDict removeAllObjects];
        }
    }

}

- (void) clearPersistedSessionAnalytics {
    @synchronized (attributeDict) {
        @synchronized (privateAttributeDict) {

            [attributeDict removeAllObjects];
            [privateAttributeDict removeAllObjects];

            NSError* error;
            [[NSFileManager defaultManager] removeItemAtPath:[NRMASAM attributeFilePath] error:&error];
            if (error) {
                NRLOG_VERBOSE(@"Failed to clear Persisted Session Analytics w/ error = %@", error);
            }

            [[NSFileManager defaultManager] removeItemAtPath:[NRMASAM privateAttributeFilePath] error:&error];
            if (error) {
                NRLOG_VERBOSE(@"Failed to clear Persisted Private Session Analytics w/ error = %@", error);
            }
        }
    }
}

- (BOOL) persistToDisk {
    NSString* currentAttributes = [self publicSessionAttributeJSONString];

    NSData* data = [currentAttributes dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        [data writeToFile:[NRMASAM attributeFilePath] atomically:true];
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL) persistPrivateAttributesToDisk {
    NSString* currentAttributes = [self privateSessionAttributeJSONString];

    NSData* data = [currentAttributes dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        [data writeToFile:[NRMASAM privateAttributeFilePath] atomically:true];

        return YES;
    }
    else {
        return NO;
    }
}

// Helpers

+(NSString*)attributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file];
}
+(NSString*)privateAttributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private];
}
@end
