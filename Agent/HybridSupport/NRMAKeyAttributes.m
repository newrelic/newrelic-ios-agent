//
//  NRMAKeyAttributes.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/14/17.
//  Copyright © 2017 New Relic. All rights reserved.
//

#import "NRMAKeyAttributes.h"
#import "NewRelicInternalUtils.h"
#import "NRMAAgentConfiguration.h"
#import "NewRelicAgentInternal.h"
#import "NRMADataToken.h"

#define UUID_KEY    @"uuid"
#define APP_VERSION_KEY @"appVersion"
#define APP_NAME_KEY    @"appName"

@implementation NRMAKeyAttributes
+ (NSDictionary*) keyAttributes: (NRMAConnectInformation*) connectionInfo {
    if (connectionInfo.applicationInformation.appName == nil ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"appName of connection information is nil"
                                     userInfo:nil];
    }
    if (connectionInfo.applicationInformation.appVersion == nil ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"appVersion of connection information is nil"
                                     userInfo:nil];

    }
    if (connectionInfo.deviceInformation.deviceId == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"deviceID of connection information is nil"
                                     userInfo:nil];

    }
    NSMutableDictionary* attributes = [NSMutableDictionary new];

    NSString* appName = connectionInfo.applicationInformation.appName;
    NSString* appVersion = connectionInfo.applicationInformation.appVersion;
    NSString* uuid = connectionInfo.deviceInformation.deviceId;

    [attributes setValue:appName forKey:APP_NAME_KEY];
    [attributes setValue:appVersion forKey:APP_VERSION_KEY];
    [attributes setValue:uuid forKey:UUID_KEY];

   return attributes;
}
@end
