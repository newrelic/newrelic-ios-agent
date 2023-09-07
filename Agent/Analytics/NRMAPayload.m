//
//  NRMAPayload.m
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAPayload.h"

@implementation NRMAPayload {
    NSString *version;
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
    [coder encodeDouble:_timestamp forKey:@"Timestamp"];
    [coder encodeObject:_accountId forKey:@"AccountId"];
    [coder encodeObject:_appId forKey:@"AppId"];
    [coder encodeObject:_id forKey:@"id"];
    [coder encodeObject:_traceId forKey:@"TraceId"];
    [coder encodeObject:_parentId forKey:@"ParentId"];
    [coder encodeObject:_trustedAccountKey forKey:@"TrustedAccountKey"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _timestamp = [coder decodeDoubleForKey:@"Timestamp"];
        _payloadType = @"mobile";
        _accountId = [coder decodeObjectForKey:@"AccountId"];
        _appId = [coder decodeObjectForKey:@"AppId"];
        _id = [coder decodeObjectForKey:@"id"];
        _traceId = [coder decodeObjectForKey:@"TraceId"];
        _parentId = [coder decodeObjectForKey:@"ParentId"];
        _trustedAccountKey = [coder decodeObjectForKey:@"TrustedAccountKey"];
        _dtEnabled = false;
        self->version = @"[0,2]";
    }
    
    return self;
}

@end
