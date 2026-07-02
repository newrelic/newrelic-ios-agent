//
//  NRMAHarvestResponse.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestResponse.h"


static const NSString* kDISABLE_STRING = @"DISABLE_NEW_RELIC";

@implementation NRMAHarvestResponse

- (int) getResponseCode
{
    if ([self isOK]) {
        return OK;
    }
    switch (self.statusCode) {
        case UNAUTHORIZED:
        case ENTITY_TOO_LARGE:
        case FORBIDDEN:
        case INVALID_AGENT_ID:
        case UNSUPPORTED_MEDIA_TYPE:
        case CONFIGURATION_UPDATE:
        case TOO_MANY_REQUESTS:
            return self.statusCode;
            break;
        default:
            return UNKNOWN;
            break;
    }
}

- (BOOL) isDisableCommand
{
    return FORBIDDEN == [self getResponseCode] && [kDISABLE_STRING isEqualToString:self.responseBody];
}


- (BOOL) isError
{
    return self.error != nil || self.statusCode == ZERO_STATUS_CODE || self.statusCode >= 400;
}
- (BOOL) isOK
{
    return ![self isError];
}

- (BOOL) isRateLimited
{
    return self.statusCode == TOO_MANY_REQUESTS;
}

- (void) parseRetryAfterFromHeaders:(NSDictionary*)headers
{
    self.retryAfterSeconds = 0;
    if (![headers isKindOfClass:[NSDictionary class]]) {
        return;
    }

    // Header field names are case-insensitive, but allHeaderFields preserves the
    // server's casing, so search for the value rather than assuming a key.
    NSString* value = nil;
    for (id key in headers) {
        if ([key isKindOfClass:[NSString class]] && [(NSString*)key caseInsensitiveCompare:@"Retry-After"] == NSOrderedSame) {
            id rawValue = headers[key];
            if ([rawValue isKindOfClass:[NSString class]]) {
                value = rawValue;
            }
            break;
        }
    }

    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (value.length == 0) {
        return;
    }

    // Retry-After is either delta-seconds (a non-negative integer) or an HTTP-date.
    NSScanner* scanner = [NSScanner scannerWithString:value];
    NSInteger seconds = 0;
    if ([scanner scanInteger:&seconds] && [scanner isAtEnd]) {
        self.retryAfterSeconds = seconds > 0 ? (NSTimeInterval)seconds : 0;
        return;
    }

    static NSDateFormatter* httpDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpDateFormatter = [[NSDateFormatter alloc] init];
        httpDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        httpDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        httpDateFormatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    });

    NSDate* retryDate = [httpDateFormatter dateFromString:value];
    if (retryDate != nil) {
        NSTimeInterval delta = [retryDate timeIntervalSinceNow];
        self.retryAfterSeconds = delta > 0 ? delta : 0;
    }
}

@end
