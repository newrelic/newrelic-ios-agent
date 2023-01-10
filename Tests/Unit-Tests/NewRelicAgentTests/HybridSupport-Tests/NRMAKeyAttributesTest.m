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
    
    NSDictionary* keyAttributes = [NRMAKeyAttributes keyAttributes:[self createValidConnectionInformation]];
    
    XCTAssertEqualObjects(attributes, keyAttributes, @"Expected keyAttributes to equal the attributes from connection information");
    XCTAssertNotNil(keyAttributes[@"appName"], @"Key attribute missing: appName");
    XCTAssertNotNil(keyAttributes[@"appVersion"], @"Key attribute missing: appVersion");
    XCTAssertNotNil(keyAttributes[@"uuid"], @"Key attribute missing: uuid");
}
- (void) testKeyAttributesInvalidInput
{
    XCTAssertNoThrow([NRMAKeyAttributes keyAttributes: [self createInvalidConnectionInformation:nil
                                                                                     appVersion:@"123"
                                                                                      packageId:@"com.test"
                                                                               useValidDeviceId: true]], @"App should not crash when an appName is nil");
    XCTAssertNoThrow([NRMAKeyAttributes keyAttributes: [self createInvalidConnectionInformation:@"test"
                                                                                     appVersion:nil
                                                                                      packageId:@"com.test"
                                                                               useValidDeviceId: true]], @"App should not crash when an appVersion is nil");
    XCTAssertNoThrow([NRMAKeyAttributes keyAttributes: [self createInvalidConnectionInformation:@"test"
                                                                                     appVersion:@"123"
                                                                                      packageId:nil
                                                                               useValidDeviceId: true]], @"App should not crash when a bundleId is nil");
    XCTAssertNoThrow([NRMAKeyAttributes keyAttributes: [self createInvalidConnectionInformation:@"test"
                                                                                     appVersion:@"123"
                                                                                      packageId:@"com.test"
                                                                               useValidDeviceId: false]], @"App should not crash when device id is nil");
    
    
    NSDictionary* keyAttributesNoName = [NRMAKeyAttributes keyAttributes:[self createInvalidConnectionInformation:nil
                                                                                                       appVersion:@"123"
                                                                                                        packageId:@"com.test"
                                                                                                 useValidDeviceId: true]];
    XCTAssertNotNil(keyAttributesNoName[@"appName"]);
    XCTAssertEqualObjects(@"", keyAttributesNoName[@"appName"]);
    
    NSDictionary* keyAttributesNoVersion = [NRMAKeyAttributes keyAttributes:[self createInvalidConnectionInformation:@"test"
                                                                                                       appVersion:nil
                                                                                                        packageId:@"com.test"
                                                                                                 useValidDeviceId: true]];
    XCTAssertNotNil(keyAttributesNoVersion[@"appVersion"]);
    XCTAssertEqualObjects(@"", keyAttributesNoVersion[@"appVersion"]);
}

- (NRMAConnectInformation*) createValidConnectionInformation
{
    NSString* appName = @"test";
    NSString* appversion = @"1.0";
    NSString* packageId = @"com.test";
    NRMAApplicationInformation* appinfo = [[NRMAApplicationInformation alloc] initWithAppName:appName
                                                                               appVersion:appversion
                                                                                 bundleId:packageId];
    
    NSDictionary* deviceInfo = [NSMutableDictionary new];
    [deviceInfo setValue:[NewRelicInternalUtils osName] forKey:kNRMADeviceInfoOSName];
    [deviceInfo setValue:[NewRelicInternalUtils osVersion] forKey:kNRMADeviceInfoOSVersion];
    [deviceInfo setValue:@"Apple Inc." forKey:kNRMADeviceInfoManufacturer];
    [deviceInfo setValue:[NewRelicInternalUtils deviceModel] forKey:kNRMADeviceInfoModel];
    [deviceInfo setValue:[NewRelicInternalUtils agentName] forKey:kNRMADeviceInfoAgentName];
    [deviceInfo setValue:@"2.123" forKey:kNRMADeviceInfoAgentVersion];
    [deviceInfo setValue:@"389C9738-A761-44DE-8A66-1668CFD67DA1" forKey:kNRMADeviceInfoDeviceId];
    
    NRMADeviceInformation* devInfo = [[NRMADeviceInformation alloc] initWithDictionary:deviceInfo];
    
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    
    connectionInformation.applicationInformation = appinfo;
    connectionInformation.deviceInformation = devInfo;
    return connectionInformation;
}

- (NRMAConnectInformation*) createInvalidConnectionInformation:(NSString *) appName
                                                    appVersion:(NSString *) appVersion
                                                     packageId:(NSString *) packageId
                                              useValidDeviceId:(BOOL) useValidDeviceId
{
    NRMAApplicationInformation* appinfo = [[NRMAApplicationInformation alloc] initWithAppName:appName
                                                                               appVersion:appVersion
                                                                                 bundleId:packageId];
    NSDictionary* deviceInfo = [NSMutableDictionary new];
    [deviceInfo setValue:[NewRelicInternalUtils osName] forKey:kNRMADeviceInfoOSName];
    [deviceInfo setValue:[NewRelicInternalUtils osVersion] forKey:kNRMADeviceInfoOSVersion];
    [deviceInfo setValue:@"Apple Inc." forKey:kNRMADeviceInfoManufacturer];
    [deviceInfo setValue:[NewRelicInternalUtils deviceModel] forKey:kNRMADeviceInfoModel];
    [deviceInfo setValue:[NewRelicInternalUtils agentName] forKey:kNRMADeviceInfoAgentName];
    [deviceInfo setValue:@"2.123" forKey:kNRMADeviceInfoAgentVersion];
    if (useValidDeviceId) {
        [deviceInfo setValue:@"389C9738-A761-44DE-8A66-1668CFD67DA1" forKey:kNRMADeviceInfoDeviceId];
    }
    
    NRMADeviceInformation* devInfo = [[NRMADeviceInformation alloc] initWithDictionary:deviceInfo];
    NRMAConnectInformation* connectionInformation = [[NRMAConnectInformation alloc] init];
    
    connectionInformation.applicationInformation = appinfo;
    connectionInformation.deviceInformation = devInfo;
    return connectionInformation;
}

@end
