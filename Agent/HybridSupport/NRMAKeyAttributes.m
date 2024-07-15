//
//  NRMAKeyAttributes.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/14/17.
//  Copyright © 2023 New Relic. All rights reserved.
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
    NSString* appName;
    NSString* appVersion;
    NSString* uuid;
    
    if (connectionInfo.applicationInformation.appName == nil ) {
        appName = @"";
        NRLOG_AGENT_ERROR(@"application name attribute of connection information is nil.");
    } else {
        appName = connectionInfo.applicationInformation.appName;
    }
    if (connectionInfo.applicationInformation.appVersion == nil ) {
        appVersion = @"";
        NRLOG_AGENT_ERROR(@"application version attribute of connection information is nil.");
    } else {
        appVersion = connectionInfo.applicationInformation.appVersion;
    }
    if (connectionInfo.deviceInformation.deviceId == nil) {
        uuid = @"";
        NRLOG_AGENT_ERROR(@"device ID attribute of connection information is nil.");
    } else {
        uuid = connectionInfo.deviceInformation.deviceId;
    }
    NSMutableDictionary* attributes = [NSMutableDictionary new];


    [attributes setValue:appName forKey:APP_NAME_KEY];
    [attributes setValue:appVersion forKey:APP_VERSION_KEY];
    [attributes setValue:uuid forKey:UUID_KEY];

   return attributes;
}
@end
