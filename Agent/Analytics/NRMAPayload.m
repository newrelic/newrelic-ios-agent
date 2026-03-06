//
//  NRMAPayload.m
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAPayload.h"

static NSString* const kTimestampKey        = @"Timestamp";
static NSString* const kAccountIdKey        = @"AccountId";
static NSString* const kAppIdKey            = @"AppId";
static NSString* const kIdKey               = @"id";
static NSString* const kTraceIdKey          = @"TraceId";
static NSString* const kParentIdKey         = @"ParentId";
static NSString* const kTrustedAccountKey   = @"TrustedAccountKey";

@implementation NRMAPayload {
    NSString *version;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
                                 accountID:(NSString*)accountId
                                 appID:(NSString*)appId
                                 traceID:(NSString*)traceId
                                 parentID:(NSString*)parentId
                                 trustedAccountKey:(NSString*)trustedAccountKey {
    self = [super init];
    if (self) {
        _timestamp = timestamp;
        _payloadType = @"mobile";
        _accountId = accountId;
        _appId = appId;
        _id = [[[[[[NSUUID UUID] UUIDString] componentsSeparatedByString:@"-"] componentsJoinedByString:@""] substringToIndex:16] lowercaseString];
        _traceId = traceId;
        _parentId = parentId;
        _trustedAccountKey = trustedAccountKey;
        _dtEnabled = false;
        self->version = @"[0,2]";
    }
    
    return self;
}

- (id)JSONObject {
    static const NSString* versionKey   = @"v";
    static const NSString* dataKey      = @"d";
    static const NSString* typeKey      = @"ty";
    static const NSString* accountKey   = @"ac";
    static const NSString* appKey       = @"ap";
    static const NSString* idKey        = @"id";
    static const NSString* traceKey     = @"tr";
    static const NSString* timeKey      = @"ti";
    static const NSString* trustKey     = @"tk";
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[timeKey] = @(self.timestamp);
    data[accountKey] = self.accountId;
    data[idKey] = self.id;
    data[appKey] = self.appId;
    data[traceKey] = self.traceId;
    data[typeKey] = self.payloadType;
    if (self.trustedAccountKey.length > 0 && self.accountId != self.trustedAccountKey) {
        data[trustKey] = self.trustedAccountKey;
    }
    
    NSDictionary *dict = @{versionKey:version, dataKey:data};

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeDouble:_timestamp forKey:kTimestampKey];
    [coder encodeObject:_accountId forKey:kAccountIdKey];
    [coder encodeObject:_appId forKey:kAppIdKey];
    [coder encodeObject:_id forKey:kIdKey];
    [coder encodeObject:_traceId forKey:kTraceIdKey];
    [coder encodeObject:_parentId forKey:kParentIdKey];
    [coder encodeObject:_trustedAccountKey forKey:kTrustedAccountKey];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _timestamp = [coder decodeDoubleForKey:kTimestampKey];
        _payloadType = @"mobile";
        _accountId = [coder decodeObjectOfClass:[NSString class] forKey:kAccountIdKey];
        _appId = [coder decodeObjectOfClass:[NSString class] forKey:kAppIdKey];
        _id = [coder decodeObjectOfClass:[NSString class] forKey:kIdKey];
        _traceId = [coder decodeObjectOfClass:[NSString class] forKey:kTraceIdKey];
        _parentId = [coder decodeObjectOfClass:[NSString class] forKey:kParentIdKey];
        _trustedAccountKey = [coder decodeObjectOfClass:[NSString class] forKey:kTrustedAccountKey];
        _dtEnabled = false;
        self->version = @"[0,2]";
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[NRMAPayload class]]) return NO;
    NRMAPayload *other = (NRMAPayload *)object;
    return self.timestamp == other.timestamp &&
           [self.payloadType isEqualToString:other.payloadType] &&
           [self.accountId isEqualToString:other.accountId] &&
           [self.appId isEqualToString:other.appId] &&
           [self.id isEqualToString:other.id] &&
           [self.traceId isEqualToString:other.traceId] &&
           [self.parentId isEqualToString:other.parentId] &&
           [self.trustedAccountKey isEqualToString:other.trustedAccountKey] &&
           self.dtEnabled == other.dtEnabled;
}

- (NSUInteger)hash {
    return self.timestamp +
           self.payloadType.hash +
           self.accountId.hash +
           self.appId.hash +
           self.id.hash +
           self.traceId.hash +
           self.parentId.hash +
           self.trustedAccountKey.hash +
           self.dtEnabled;
}

@end
