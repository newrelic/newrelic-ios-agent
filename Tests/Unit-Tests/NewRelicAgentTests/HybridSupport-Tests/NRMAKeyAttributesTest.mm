//
//  NRMAKeyAttributesTest.m
//  Agent_Tests
//
//  Created on 6/3/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAKeyAttributes.h"
#import "NRMAConnectInformation.h"
#import "NRMAAgentConfiguration.h"
#import "NewRelicInternalUtils.h"
#import "NRMADataToken.h"

#define UUID_KEY    @"uuid"
#define APP_VERSION_KEY @"appVersion"
#define APP_NAME_KEY    @"appName"

@interface NRMAKeyAttributesTest : XCTestCase

@end

@implementation NRMAKeyAttributesTest

- (void) testKeyAttributesCorrectness
{
    NSMutableDictionary* attributes = [NSMutableDictionary new];
    
    NSString* appName = @"test";
    NSString* appVersion = @"1.0";
    NSString* uuid = @"389C9738-A761-44DE-8A66-1668CFD67DA1";

    [attributes setValue:appName forKey:@"appName"];
    [attributes setValue:appVersion forKey:@"appVersion"];
    [attributes setValue:uuid forKey:@"uuid"];
    
    NSMutableDictionary* keyAttributes = [NSMutableDictionary new];
    NRMAConnectInformation* connInfo = [self createConnectionInformation];

    [keyAttributes setValue:connInfo.applicationInformation.appName forKey:APP_NAME_KEY];
    [keyAttributes setValue:connInfo.applicationInformation.appVersion forKey:APP_VERSION_KEY];
    [keyAttributes setValue:connInfo.deviceInformation.deviceId forKey:UUID_KEY];

    XCTAssertEqualObjects(attributes, keyAttributes, @"Expected keyAttributes to equal the attributes from connection information");
    XCTAssertNotNil(keyAttributes[@"appName"], @"Key attribute missing: appName");
    XCTAssertNotNil(keyAttributes[@"appVersion"], @"Key attribute missing: appVersion");
    XCTAssertNotNil(keyAttributes[@"uuid"], @"Key attribute missing: uuid");
}

- (NRMAConnectInformation*) createConnectionInformation
{
    NSString* appName = @"test";
    NSString* appversion = @"1.0";
    NSString* packageId = @"com.test";
    NRMAApplicationInformation* appinfo = [[NRMAApplicationInformation alloc] initWithAppName:appName
                                                                               appVersion:appversion
                                                                                 bundleId:packageId];
    NRMADeviceInformation* devInfo = [[NRMADeviceInformation alloc] init];
    devInfo.osName = [NewRelicInternalUtils osName];
    devInfo.osVersion = [NewRelicInternalUtils osVersion];
    devInfo.manufacturer = @"Apple Inc.";
    devInfo.model = [NewRelicInternalUtils deviceModel];
    devInfo.agentName = [NewRelicInternalUtils agentName];
    devInfo.agentVersion = @"2.123";
    devInfo.deviceId =@"389C9738-A761-44DE-8A66-1668CFD67DA1";
    
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    
    connectionInformation.applicationInformation = appinfo;
    connectionInformation.deviceInformation = devInfo;
    return connectionInformation;
}

@end
