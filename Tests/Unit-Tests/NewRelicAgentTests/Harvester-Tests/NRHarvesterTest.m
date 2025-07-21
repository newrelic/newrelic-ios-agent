//
//  NRMAHarvesterTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRHarvesterTest.h"
#import "NRMAMethodSwizzling.h"
#import <OCMock/OCMock.h>
#import <objc/runtime.h>
#import "NRTestConstants.h"
#import "NRMATraceConfiguration.h"
#import "NewRelicAgent+Development.h"
#import "NRMAHarvestController.h"
#import "NRMAAppToken.h"

@interface NSBundle (AHHHH)
+ (NSBundle*) NRMA__mainBundle;
@end

@interface NRMAHarvester ()
- (NRMAHarvesterConnection*)connection;
- (void)connected;
- (void) disconnected;
- (void) uninitialized;
@end

@implementation NRMAHarvestAwareHelper

- (void) onHarvestStart
{
    self.harvestedStart = YES;
}
- (void) onHarvestStop
{
    self.harvestedStop = YES;
}
- (void) onHarvestBefore
{
    self.harvestedBefore = YES;
}
- (void) onHarvest
{
    self.harvested = YES;
}
- (void) onHarvestError
{
    self.harvestedError = YES;
}
- (void) onHarvestComplete
{
    self.harvestedComplete = YES;
}
@end

@implementation NRMAHarvesterTest

- (void) setUp
{
    [super setUp];
    
    [[NSUserDefaults standardUserDefaults] setObject:@{} forKey:kNRMAHarvesterConfigurationStoreKey];
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:kNRMAApplicationIdentifierKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];

    harvester = [[NRMAHarvester alloc] init];
    [harvester setAgentConfiguration:agentConfig];
    
    id mockNSURLSession = [self makeMockURLSession];
    harvester.connection.harvestSession = mockNSURLSession;

    harvestAwareHelper = [[NRMAHarvestAwareHelper alloc] init];
    [harvester addHarvestAwareObject:harvestAwareHelper];
}

- (void)tearDown
{
    [super tearDown];
}

- (NRMAHarvesterConfiguration*) makeHarvestConfig
{
    NRMAHarvesterConfiguration* config = [[NRMAHarvesterConfiguration alloc] init];
    config.application_token = kNRMA_ENABLED_STAGING_APP_TOKEN;
    config.collect_network_errors = YES;
    config.cross_process_id = @"cross_process_id";
    config.data_report_period = 60;
    config.data_token = [[NRMADataToken alloc] init];
    config.data_token.clusterAgentId = 36920;
    config.data_token.realAgentId = 36921;
    config.error_limit = 50;
    config.report_max_transaction_age = 600;
    config.report_max_transaction_count =1000;
    config.response_body_limit = 2048;
    config.server_timestamp = 1379548800;
    config.stack_trace_limit = 100;
    config.account_id = 190;
    config.application_id = 36920;
    config.trusted_account_key = @"123";
    config.request_header_map = [NSDictionary dictionary];
    config.encoding_key = @"encoding_key";
    config.at_capture = [NRMATraceConfigurations defaultTraceConfigurations];

    config.log_reporting_level = @"WARN";
    config.sampling_rate = 100.0;
    config.entity_guid = @"";
    config.has_log_reporting_config = YES;
    config.log_reporting_enabled = NO;
    // MSR Section
    config.has_session_replay_config = YES;
    config.session_replay_enabled = NO;
    config.session_replay_sampling_rate = 100.0;
    config.session_replay_error_sampling_rate = 100.0;
    config.session_replay_mode = SessionReplayMaskingModeDefault;

    config.session_replay_maskApplicationText = YES;
    config.session_replay_maskUserInputText = YES;
    config.session_replay_maskAllUserTouches = YES;
    config.session_replay_maskAllImages = YES;
    
    config.session_replay_customRules = [NSMutableArray array];;

    // Lists for tracking masked elements in SessionReplay
    config.session_replay_maskedAccessibilityIdentifiers = [NSMutableArray array];
    config.session_replay_maskedClassNames = [NSMutableArray array];

    // Lists for tracking unmasked elements in SessionReplay
    config.session_replay_unmaskedAccessibilityIdentifiers = [NSMutableArray array];
    config.session_replay_unmaskedClassNames = [NSMutableArray array];


    // End MSR Section
    return config;
}

- (id) makeMockURLSession {
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://staging-mobile-collector.newrelic.com"] statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    NRMAHarvesterConfiguration* config = [self makeHarvestConfig];
        
    NSData *data = [NSJSONSerialization dataWithJSONObject:[config asDictionary] options:NSJSONWritingPrettyPrinted error:nil];
    
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler(data, bresponse, nil);
    }] resume];
    
    return mockNSURLSession;
}

- (id) makeMockURLSessionResponseError:(NSError*) error statusCode:(NSInteger)statusCode {
    __block NSURLResponse* bresponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://staging-mobile-collector.newrelic.com"] statusCode:statusCode HTTPVersion:@"1.1" headerFields:nil];
    
    id mockNSURLSession = [OCMockObject mockForClass:NSURLSession.class];
    [[[mockNSURLSession stub] classMethod] andReturn:mockNSURLSession];

    id mockUploadTask = [OCMockObject mockForClass:NSURLSessionUploadTask.class];

    __block void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

    [[[[mockNSURLSession stub] andReturn:mockUploadTask] andDo:^(NSInvocation * invoke) {
        [invoke getArgument:&completionHandler atIndex:4];
    }] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[mockUploadTask stub] andDo:^(NSInvocation *invoke) {
        completionHandler([@"DISABLE_NEW_RELIC" dataUsingEncoding:NSUTF8StringEncoding], bresponse, error);
    }] resume];
    
    return mockNSURLSession;
}

- (void) testHarvestConfiguration
{
    NRMAHarvesterConfiguration* config = [self makeHarvestConfig];
    
    XCTAssertTrue([config isEqual:config], @"isEqual is correct"); // LOL
    NSLog(@"config = @+%@", config);
    NRMAHarvesterConfiguration *secondConfig = [[NRMAHarvesterConfiguration alloc] initWithDictionary:[config asDictionary]];
    NSLog(@"secondConfig = @+%@", secondConfig);

    NRMAHarvesterConfiguration *thirdConfig = [[NRMAHarvesterConfiguration alloc] initWithDictionary:[config asDictionary]];
    XCTAssertTrue([config isEqual:thirdConfig], @"test asDictionary and initWithDictionary is correct");
}

- (void) testBadHarvestConfiguration {

    // Test what happens if any value is missing from passed dictionary

    NRMAHarvesterConfiguration* config = [[NRMAHarvesterConfiguration alloc] initWithDictionary:[NSDictionary dictionary]];
    XCTAssertEqual(NRMA_DEFAULT_REPORT_PERIOD, config.data_report_period, @"A bad dictionary should parse default report period to its default.");
    // if kNRMA_COLLECT_NETWORK_ERRORS is missing.
    XCTAssertEqual(true, config.collect_network_errors, @"A bad dictionary should parse default report period to its default.");
    // if kNRMA_ERROR_LIMIT is missing
    XCTAssertEqual(NRMA_DEFAULT_ERROR_LIMIT, config.error_limit, @"A bad dictionary should parse default error limit to its default.");
    // if kNRMA_REPORT_MAX_TRANSACTION_AGE is missing
    XCTAssertEqual(NRMA_DEFAULT_MAX_TRANSACTION_AGE, config.report_max_transaction_age, @"A bad dictionary should parse default max transaction aget limit to its default.");
    // if kNRMA_REPORT_MAX_TRANSACTION_COUNT is missing
    XCTAssertEqual(NRMA_DEFAULT_MAX_TRANSACTION_COUNT, config.report_max_transaction_count, @"A bad dictionary should parse max transactions to its default.");
    // if kNRMA_RESPONSE_BODY_LIMIT is missing
    XCTAssertEqual(NRMA_DEFAULT_RESPONSE_BODY_LIMIT, config.response_body_limit, @"A bad dictionary should parse response body limit to its default.");
    // if kNRMA_STACK_TRACE_LIMIT is missing
    XCTAssertEqual(NRMA_DEFAULT_STACK_TRACE_LIMIT, config.stack_trace_limit, @"A bad dictionary should parse response body limit to its default.");
    // if kNRMA_AT_MAX_SIZE is missing
    XCTAssertEqual(NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SIZE, config.activity_trace_max_size, @"A bad dictionary should parse activity trace max size limit to its default.");
}

- (void) testActivityTraceConfiguration
{
    NSArray* at_capture;
    NRMATraceConfigurations *traceConfigurations;

    // Test a config which has metric pattern criteria
    NSString *configWithCriterion = @"[1,[[\"/*\",1,[[\"Metric/Pattern\",1,2,3.0,4.0]]]]]";
    at_capture = [NRMAJSON JSONObjectWithData:[configWithCriterion dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    traceConfigurations = [[NRMATraceConfigurations alloc] initWithArray:at_capture];
    XCTAssertNotNil(traceConfigurations, @"Trace configurations is nil");
    XCTAssertEqual(1, traceConfigurations.maxTotalTraceCount, @"Max trace count should be 1");
    XCTAssertNotNil(traceConfigurations.activityTraceConfigurations, @"Activity configuration arrasy is nil");
    XCTAssertEqual(1, (int)traceConfigurations.activityTraceConfigurations.count, @"Should be 1 activity trace configuration");

    NRMATraceConfiguration* configuration = [traceConfigurations.activityTraceConfigurations objectAtIndex:0];
    XCTAssertNotNil(configuration, @"Trace configuration is nil");

    XCTAssertEqualObjects(@"/*", configuration.activityTraceNamePattern, @"Trace name pattern is not correct");
}

- (void) testBadStoredDataRecover
{
    NRMAHarvester* newHarvester = [[NRMAHarvester alloc] init];
    id mockNSURLSession = [self makeMockURLSession];
    
    newHarvester.connection.harvestSession = mockNSURLSession;
    
    id dataMock = [OCMockObject partialMockForObject:[newHarvester harvestData]];
    [[dataMock expect] clear];
    id harvesterMock = [OCMockObject partialMockForObject:newHarvester];
    [harvesterMock setAgentConfiguration:agentConfig];

    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_DISCONNECTED];

    id connectionMock = [OCMockObject partialMockForObject:[newHarvester connection]];
    [[[connectionMock stub] andForwardToRealObject] sendConnect];

    [harvesterMock execute];
    [harvesterMock execute];
    [harvesterMock verify];

    [dataMock verify]; //verify the harvest data is cleared after a successful harvest
    [connectionMock stopMocking];
    [harvesterMock stopMocking];
    [dataMock stopMocking];
}

- (void) testStoredData
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id mockNSURLSession = [self makeMockURLSession];

    XCTAssertEqual(harvester.currentState,NRMA_HARVEST_UNINITIALIZED,@"expected uninitialized");
    [harvester execute];

    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_UNINITIALIZED) {};
    
    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_DISCONNECTED, @"expected disconnected");
    [harvester execute];

    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_DISCONNECTED) {};
    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_CONNECTED, @"expected connected");

    //at this point there should be stored data
    XCTAssertNotNil([defaults objectForKey:kNRMAHarvesterConfigurationStoreKey], @"this should have been set");
    
    NRMAHarvester *newHarvester = [[NRMAHarvester alloc] init];
    
    newHarvester.connection.harvestSession = mockNSURLSession;
    [newHarvester setAgentConfiguration:agentConfig];

    id harvesterMock = [OCMockObject partialMockForObject:newHarvester];
    [harvesterMock setAgentConfiguration:agentConfig];

    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_DISCONNECTED];
    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_CONNECTED];

    id connectionMock = [OCMockObject niceMockForClass:[NRMAHarvesterConnection class]];
    [[connectionMock reject] sendConnect];

    [harvesterMock execute];
    [harvesterMock execute];
    [harvesterMock verify];
    [connectionMock verify];

    XCTAssertEqual([harvesterMock currentState], NRMA_HARVEST_CONNECTED, @"we should be connected with stored credentials");

    [connectionMock  stopMocking];
    [harvesterMock stopMocking];
}

- (void) testOfflineStorage
{
    XCTAssertNoThrow([NewRelic setMaxOfflineStorageSize:1000]);
    [NewRelic enableFeatures:NRFeatureFlag_OfflineStorage];

    NRMAHarvester* newHarvester = [[NRMAHarvester alloc] init];
    id mockNSURLSession = [self makeMockURLSessionResponseError:[[NSError alloc] initWithDomain:@"" code:NSURLErrorNotConnectedToInternet userInfo:nil] statusCode:200];
    newHarvester.connection.harvestSession = mockNSURLSession;

    id mockHarvester = [OCMockObject partialMockForObject:newHarvester];
    [[[mockHarvester stub] andReturn:[NRMAHarvesterConfiguration new]] harvesterConfiguration];
    [mockHarvester setAgentConfiguration:agentConfig];
    
    id connectionMock = [OCMockObject partialMockForObject:[newHarvester connection]];
    [connectionMock setApplicationToken:@"APP_TOKEN"];
    
    NRMAHarvesterConfiguration* v3config = [[NRMAHarvesterConfiguration alloc] init];
    v3config.collect_network_errors = YES;
    v3config.cross_process_id = @"cross_process_id";
    v3config.data_report_period = 60;
    v3config.data_token = [[NRMADataToken alloc] init];
    v3config.data_token.clusterAgentId = 36920;
    v3config.data_token.realAgentId = 36921;
    v3config.error_limit = 50;
    v3config.report_max_transaction_age = 600;
    v3config.report_max_transaction_count =1000;
    v3config.response_body_limit = 2048;
    v3config.server_timestamp = 1379548800;
    v3config.stack_trace_limit = 100;
    v3config.account_id = 1;
    v3config.application_id = 1;
    v3config.encoding_key = @"encoding_key";
    v3config.application_token = @"APP_TOKEN";
    [[[mockHarvester stub] andReturn:v3config] fetchHarvestConfiguration];

    [mockHarvester connected];
   
    NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    NSArray<NSData *> * offlineData = [newHarvester.connection getOfflineData];
    XCTAssertTrue(offlineData.count > 0);
    XCTAssertTrue(currentOfflineStorageSize > 0);

    mockNSURLSession = [self makeMockURLSession];
    newHarvester.connection.harvestSession = mockNSURLSession;
    
    [mockHarvester connected];
    
    offlineData = [newHarvester.connection getOfflineData];
    currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    XCTAssertTrue(offlineData.count == 0);
    XCTAssertTrue(currentOfflineStorageSize == 0);

    [mockHarvester stopMocking];
    [connectionMock stopMocking];
    [NewRelic disableFeatures:NRFeatureFlag_OfflineStorage];
}

- (void) testOfflineStorageDisabled
{
    [NewRelic disableFeatures:NRFeatureFlag_OfflineStorage];
    XCTAssertNoThrow([NewRelic setMaxOfflineStorageSize:1000]);

    NRMAHarvester* newHarvester = [[NRMAHarvester alloc] init];
    id mockNSURLSession = [self makeMockURLSessionResponseError:[[NSError alloc] initWithDomain:@"" code:NSURLErrorNotConnectedToInternet userInfo:nil] statusCode:200];
    newHarvester.connection.harvestSession = mockNSURLSession;

    id mockHarvester = [OCMockObject partialMockForObject:newHarvester];
    [[[mockHarvester stub] andReturn:[NRMAHarvesterConfiguration new]] harvesterConfiguration];
    [mockHarvester setAgentConfiguration:agentConfig];
    
    id connectionMock = [OCMockObject partialMockForObject:[newHarvester connection]];
    [connectionMock setApplicationToken:@"APP_TOKEN"];
    
    NRMAHarvesterConfiguration* v3config = [[NRMAHarvesterConfiguration alloc] init];
    v3config.collect_network_errors = YES;
    v3config.cross_process_id = @"cross_process_id";
    v3config.data_report_period = 60;
    v3config.data_token = [[NRMADataToken alloc] init];
    v3config.data_token.clusterAgentId = 36920;
    v3config.data_token.realAgentId = 36921;
    v3config.error_limit = 50;
    v3config.report_max_transaction_age = 600;
    v3config.report_max_transaction_count =1000;
    v3config.response_body_limit = 2048;
    v3config.server_timestamp = 1379548800;
    v3config.stack_trace_limit = 100;
    v3config.account_id = 1;
    v3config.application_id = 1;
    v3config.encoding_key = @"encoding_key";
    v3config.application_token = @"APP_TOKEN";
    [[[mockHarvester stub] andReturn:v3config] fetchHarvestConfiguration];

    [mockHarvester connected];
   
    NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    NSArray<NSData *> * offlineData = [newHarvester.connection getOfflineData];
    XCTAssertTrue(offlineData.count == 0);
    XCTAssertTrue(currentOfflineStorageSize == 0);

    mockNSURLSession = [self makeMockURLSession];
    newHarvester.connection.harvestSession = mockNSURLSession;
    
    [mockHarvester connected];
    
    offlineData = [newHarvester.connection getOfflineData];
    currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    XCTAssertTrue(offlineData.count == 0);
    XCTAssertTrue(currentOfflineStorageSize == 0);

    [mockHarvester stopMocking];
    [connectionMock stopMocking];
}

// TODO: Reenable/rewrite these tests related to Harvester/Stored Data. JIRA: NR-96516
//- (void) testBadStoredDataRecover
//{
//    NRMAHarvesterConfiguration* config = [[NRMAHarvesterConfiguration alloc] init];
//    config.collect_network_errors = YES;
//    config.cross_process_id = @"cross_process_id";
//    config.data_report_period = 60;
//    config.data_token = [[NRMADataToken alloc] init];
//    config.data_token.clusterAgentId = -1;
//    config.data_token.realAgentId = -1;
//    config.error_limit = 50;
//    config.report_max_transaction_age = 600;
//    config.report_max_transaction_count =1000;
//    config.response_body_limit = 2048;
//    config.server_timestamp = 1379548800;
//    config.stack_trace_limit = 100;
//
//    [[NSUserDefaults standardUserDefaults] setObject:[config asDictionary] forKey:kNRMAHarvesterConfigurationStoreKey];
//    [[NSUserDefaults standardUserDefaults]synchronize];
//
//    NRMAHarvester* newHarvester = [[NRMAHarvester alloc] init];
//    id dataMock = [OCMockObject partialMockForObject:[newHarvester harvestData]];
//    [[dataMock expect] clear];
//    id harvesterMock = [OCMockObject partialMockForObject:newHarvester];
//    //[newHarvester setAgentConfiguration:agentConfig];
//    [harvesterMock setAgentConfiguration:agentConfig];
//
//    //[[harvesterMock expect] andForwardToRealObject]
//    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_DISCONNECTED];
//
//    id connectionMock = [OCMockObject partialMockForObject:[newHarvester connection]];
//    [[[connectionMock stub] andForwardToRealObject] sendConnect];
//
//    [harvesterMock execute];
//    [harvesterMock execute];
//    [harvesterMock verify];
//    //[connectionMock verify];
//    [dataMock verify]; //verify the harvest data is cleared after a successful harvest
//    [connectionMock stopMocking];
//    [harvesterMock stopMocking];
//    [dataMock stopMocking];
//}
//
//- (void) testStoredData
//{
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//
//    XCTAssertEqual(harvester.currentState,NRMA_HARVEST_UNINITIALIZED,@"expected uninitialized");
//    [harvester execute];
//
//    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_UNINITIALIZED) {};
//
//    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_DISCONNECTED, @"expected disconnected");
//    [harvester execute];
//
//    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_DISCONNECTED) {};
//    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_CONNECTED, @"expected connected");
//
//    //at this point there should be stored data
//    XCTAssertNotNil([defaults objectForKey:kNRMAHarvesterConfigurationStoreKey], @"this should have been set");
//
//    NRMAHarvester* newHarvester = [[NRMAHarvester alloc] init];
//    id harvesterMock = [OCMockObject partialMockForObject:newHarvester];
//    //[newHarvester setAgentConfiguration:agentConfig];
//    [harvesterMock setAgentConfiguration:agentConfig];
//
//    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_DISCONNECTED];
//    [[[harvesterMock expect] andForwardToRealObject] transition:NRMA_HARVEST_CONNECTED];
//
//    id connectionMock = [OCMockObject niceMockForClass:[NRMAHarvesterConnection class]];
//    [[connectionMock reject] sendConnect];
//
//    [harvesterMock execute];
//    [harvesterMock execute];
//    [harvesterMock verify];
//    [connectionMock verify];
//
//    XCTAssertEqual([harvesterMock currentState], NRMA_HARVEST_CONNECTED, @"we should be connected with stored credentials");
//
//    [connectionMock  stopMocking];
//    [harvesterMock stopMocking];
//}

- (void) testMayUseStoredConfiguration
{
    NRMAHarvesterConfiguration* config = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvester saveHarvesterConfiguration:config];
    XCTAssertNotNil([harvester fetchHarvestConfiguration], @"Expected saved configuration to be returned");
}

- (void) testMayUseStoredConfigurationWhenDeviceInfoChanged
{
    NRMAHarvesterConfiguration* config = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvester saveHarvesterConfiguration:config];

    // Pretend the app version changed
    [[[self class] fakeInfoDictionary] setObject:@"9000.0" forKey:@"CFBundleShortVersionString"];

    // Cannot use saved configuration because app version has changed
    XCTAssertNil([harvester fetchHarvestConfiguration], @"Expected saved configuration to not be returned");
}

- (void) testDefaultConfigurationIsNotValid
{
    NRMAHarvesterConfiguration* config = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvester saveHarvesterConfiguration:config];
    
    XCTAssertFalse([harvester fetchHarvestConfiguration].isValid, @"Expected an invalid default configuration");
}

- (void) testConfigurationWithTokenAndIdsIsValid
{
    NRMAHarvesterConfiguration* config = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    config.data_token = [[NRMADataToken alloc] init];
    config.data_token.clusterAgentId = 36920;
    config.data_token.realAgentId = 36921;
    config.application_id = 235225;
    config.account_id = 24523112;
    [harvester saveHarvesterConfiguration:config];
    
    XCTAssertTrue([harvester fetchHarvestConfiguration].isValid, @"Expected a valid default configuration");
}

- (void) testMigrationFromV3toV4ConnectEndpoint
{
    NRMAHarvester* aHarvester = [[NRMAHarvester alloc] init];
    [aHarvester setAgentConfiguration:agentConfig];
    id mockNSURLSession = [self makeMockURLSession];
    
    aHarvester.connection.harvestSession = mockNSURLSession;

    // ensure there is no lingering harvest configuration
    XCTAssertNil([aHarvester fetchHarvestConfiguration]);

    [aHarvester execute]; // uninitialized -> disconnected
    [aHarvester execute]; // disconnected -> connected

    // we have already connected to v4, so we fake v3 by unsetting the accountID and appID
    NRMAHarvesterConfiguration* currentConfig = [aHarvester fetchHarvestConfiguration];
    currentConfig.account_id = 0;
    currentConfig.application_id = 0;
    currentConfig.data_token.clusterAgentId = 0;

    // ensure we are connected via expected v3 configuration
    [aHarvester saveHarvesterConfiguration:currentConfig];
    XCTAssertEqual(aHarvester.currentState, NRMA_HARVEST_CONNECTED);
    XCTAssertFalse([[aHarvester fetchHarvestConfiguration] isValid]);
    XCTAssertEqual(0, [aHarvester fetchHarvestConfiguration].account_id);
    XCTAssertEqual(0, [aHarvester fetchHarvestConfiguration].application_id);

    [aHarvester execute]; // connected -> connected -- should force a reconnect via v4
    XCTAssertEqual(aHarvester.currentState, NRMA_HARVEST_CONNECTED);
    XCTAssertTrue([[aHarvester fetchHarvestConfiguration] isValid]);
    XCTAssertEqual(190, [aHarvester fetchHarvestConfiguration].account_id);
    XCTAssertEqual(36920, [aHarvester fetchHarvestConfiguration].application_id);

    aHarvester = nil;
}

- (void) testUninitializedToConnected
{
    XCTAssertEqual(harvester.currentState,NRMA_HARVEST_UNINITIALIZED,@"expected uninitialized");

    //uninitialized -> disconnected
    [harvester execute];
    
    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_UNINITIALIZED) {};
    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_DISCONNECTED, @"expected disconnected");

    //Disconnected -> connected
    [harvester execute];

    while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_DISCONNECTED) {};
    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_CONNECTED, @"expected connected");
}

- (void) testUninitializedToDisabled
{
    id mockNSURLSession = [self makeMockURLSessionResponseError:[NSError errorWithDomain:@"" code:403 userInfo:@{@"Error reason": @"Invalid Input"}] statusCode:403];
    harvester.connection.harvestSession = mockNSURLSession;

   XCTAssertEqual(harvester.currentState, NRMA_HARVEST_UNINITIALIZED, @"expected uninitizlized");
   [harvester execute];


   while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_UNINITIALIZED) {};
    XCTAssertEqual(harvester.currentState, NRMA_HARVEST_DISCONNECTED, @"expected disconnected");

   [harvester execute];

   while (CFRunLoopGetCurrent() && harvester.currentState == NRMA_HARVEST_DISCONNECTED) {};
   XCTAssertEqual(harvester.currentState, NRMA_HARVEST_DISABLED, @"expected disabled");
}

- (void) testAppVersionUsesCFBundleShortVersionString
{
    NSString *realBundleVersion = [[[self class] fakeInfoDictionary] objectForKey:@"CFBundleShortVersionString"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [NewRelic setApplicationVersion:nil];
#pragma clang diagnsotic pop
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appVersion, realBundleVersion,
                   @"appInfo.appVersion should equal '%@' but is '%@'",
                   realBundleVersion, info.applicationInformation.appVersion);
}

- (void) testAppVersionUsesOverride
{
    NSString *overrideVersion = @"9.5.4.1";

    [NewRelic setApplicationVersion:overrideVersion];
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appVersion, overrideVersion,
                   @"appInfo.appVersion should equal '%@' but is '%@'",
                   overrideVersion, info.applicationInformation.appVersion);

    [NewRelic setApplicationVersion:@""];
}

- (void) testAppVersionClearsOverride
{
    NSString *realBundleVersion = [[[self class] fakeInfoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *overrideVersion = @"9.5.4.1";

    [NewRelic setApplicationVersion:overrideVersion];
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [NewRelic setApplicationVersion:nil];
#pragma clang diagnostic pop
    info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appVersion, realBundleVersion,
                   @"appInfo.appVersion should equal '%@' but is '%@'",
                   realBundleVersion, info.applicationInformation.appVersion);
    [NewRelic setApplicationVersion:@""];
}

- (void) testBuildVersionUsesCFBundleVersion
{
    NSString *realBundleVersion = [[[self class] fakeInfoDictionary] objectForKey:@"CFBundleVersion"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [NewRelic setApplicationVersion:nil];
#pragma clang diagnostic pop
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appBuild, realBundleVersion,
                   @"appInfo.appBuild should equal '%@' but is '%@'",
                   realBundleVersion, info.applicationInformation.appVersion);
}

- (void) testBuildVersionUsesOverride
{
    NSString *overrideBuild = @"9541";

    [NewRelic setApplicationBuild:overrideBuild];
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appBuild, overrideBuild,
                   @"appInfo.appBuild should equal '%@' but is '%@'",
                   overrideBuild, info.applicationInformation.appBuild);

    [NewRelic setApplicationVersion:@""];
}

- (void) testBuildVersionClearsOverride
{
    NSString *realBundleVersion = [[[self class] fakeInfoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *overrideVersion = @"9541";

    [NewRelic setApplicationBuild:overrideVersion];
    NRMAConnectInformation *info = [NRMAAgentConfiguration connectionInformation];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [NewRelic setApplicationBuild:nil];
#pragma clang diagnostic pop
    info = [NRMAAgentConfiguration connectionInformation];

    XCTAssertEqual(info.applicationInformation.appBuild, realBundleVersion,
                   @"appInfo.appBuild should equal '%@' but is '%@'",
                   realBundleVersion, info.applicationInformation.appBuild);
    [NewRelic setApplicationBuild:@""];
}


- (void) testDisconnectedThrowsException
{
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    [[[mockHarvester stub] andReturn:nil] harvestData];
    [harvester uninitialized];
    XCTAssertNoThrow([harvester disconnected],@"");
    [mockHarvester stopMocking];
}

- (void) testConnectedThrowException
{
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    id mockConnection = [OCMockObject partialMockForObject:[mockHarvester connection]];
    [[[mockHarvester stub] andReturn:[NRMAHarvesterConfiguration new]] harvesterConfiguration];

    [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
        @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    }] sendData:OCMOCK_ANY];

     XCTAssertNoThrow([mockHarvester connected],@"assert we don't crash if something goes wrong in connected");

    [mockHarvester stopMocking];
    [mockConnection stopMocking];
}

- (void) testBadTokenResponsesDontCrashApp {
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    id mockConnection = [OCMockObject partialMockForObject:[mockHarvester connection]];
    [[[mockHarvester stub] andReturn:[NRMAHarvesterConfiguration new]] harvesterConfiguration];
    
    [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
        @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    }] sendConnect];
    
    NRMAHarvestResponse* request = [[NRMAHarvestResponse alloc] init];
    request.statusCode = INVALID_AGENT_ID;
    
    [[[mockConnection stub] andReturn:request] sendData:OCMOCK_ANY];

    XCTAssertNoThrow([mockHarvester connected],@"assert we don't crash if something goes wrong in connected");
    
    [mockHarvester stopMocking];
    [mockConnection stopMocking];
}

- (void) testConfigUpdateResponse {
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    id mockConnection = [OCMockObject partialMockForObject:[mockHarvester connection]];
    [[[mockHarvester stub] andReturn:[NRMAHarvesterConfiguration new]] harvesterConfiguration];

    [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
        @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    }] sendConnect];

    NRMAHarvestResponse* request = [[NRMAHarvestResponse alloc] init];
    request.statusCode = CONFIGURATION_UPDATE;

    [[[mockConnection stub] andReturn:request] sendData:OCMOCK_ANY];

    XCTAssertNoThrow([mockHarvester connected],@"assert we don't crash if something goes wrong in connected");

    [mockHarvester stopMocking];
    [mockConnection stopMocking];
}

- (void) testConectedv3AppsDontCrashApp {
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    id mockConnection = [OCMockObject partialMockForObject:[mockHarvester connection]];
    NRMAHarvesterConfiguration* v3config = [[NRMAHarvesterConfiguration alloc] init];
    v3config.collect_network_errors = YES;
    v3config.cross_process_id = @"cross_process_id";
    v3config.data_report_period = 60;
    v3config.data_token = [[NRMADataToken alloc] init];
    v3config.data_token.clusterAgentId = 36920;
    v3config.data_token.realAgentId = 36921;
    v3config.error_limit = 50;
    v3config.report_max_transaction_age = 600;
    v3config.report_max_transaction_count =1000;
    v3config.response_body_limit = 2048;
    v3config.server_timestamp = 1379548800;
    v3config.stack_trace_limit = 100;
    v3config.account_id = 0;
    v3config.application_id = 0;
    v3config.encoding_key = @"encoding_key";
    [[[mockHarvester stub] andReturn:v3config] fetchHarvestConfiguration];
    
    [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
        @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    }] sendData:OCMOCK_ANY];
    
    XCTAssertNoThrow([mockHarvester connected],@"assert we don't crash if something goes wrong in connected");
    
    [mockHarvester stopMocking];
    [mockConnection stopMocking];
}

// TODO: LogReporting Add test for entity_guid: and log_reporting: { enabled: , level: }

- (void) testConnectedv5Apps{
    id mockHarvester = [OCMockObject partialMockForObject:harvester];
    id mockConnection = [OCMockObject partialMockForObject:[mockHarvester connection]];
    NRMAHarvesterConfiguration* v5config = [[NRMAHarvesterConfiguration alloc] init];
    v5config.collect_network_errors = YES;
    v5config.cross_process_id = @"cross_process_id";
    v5config.data_report_period = 60;
    v5config.data_token = [[NRMADataToken alloc] init];
    v5config.data_token.clusterAgentId = 36920;
    v5config.data_token.realAgentId = 36921;
    v5config.error_limit = 50;
    v5config.report_max_transaction_age = 600;
    v5config.report_max_transaction_count =1000;
    v5config.response_body_limit = 2048;
    v5config.server_timestamp = 1379548800;
    v5config.stack_trace_limit = 100;
    v5config.account_id = 0;
    v5config.application_id = 0;
    v5config.encoding_key = @"encoding_key";
    v5config.entity_guid = @"ENTITYGUID";
    v5config.request_header_map = [NSDictionary dictionary];
    v5config.at_capture = [NRMATraceConfigurations defaultTraceConfigurations];
    v5config.log_reporting_level = @"WARN";
    v5config.sampling_rate = 100.0;

    [[[mockHarvester stub] andReturn:v5config] fetchHarvestConfiguration];

    [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
        @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    }] sendData:OCMOCK_ANY];

    XCTAssertNoThrow([mockHarvester connected],@"assert we don't crash if something goes wrong in connected");

    [mockHarvester stopMocking];
    [mockConnection stopMocking];
}

@end
