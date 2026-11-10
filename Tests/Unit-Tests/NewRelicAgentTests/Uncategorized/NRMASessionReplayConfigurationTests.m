//
//  NRMASessionReplayConfigurationTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Coverage for the public session replay configuration getter, which external
//  replay sources (the Flutter agent) read to follow the native agent's decisions.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NewRelic.h"
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConfiguration.h"
#import "NRMAAgentConfiguration.h"
#import "NRMASupportMetricHelper.h"
#import "NRMATaskQueue.h"
#import <NewRelic/NewRelic-Swift.h>

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@interface NRMASessionReplayConfigurationTests : XCTestCase
@property id mockHarvestController;
@property id mockAgentInternal;
@property NewRelicAgentInternal *agent;
@property SessionReplayManager *manager;
@property NRMAHarvesterConfiguration *config;
@end

@implementation NRMASessionReplayConfigurationTests

// The masking lists are backed by process-wide arrays in NRMAAgentConfiguration, so every
// name a test adds must be removed again or it leaks into later tests.
static NSArray<NSString *> *testRuleNames(void)
{
    return @[@"LocalSecretView", @"RemoteSecretView", @"RemotePublicView", @"remote-private", @"remote-public", @"AddedLater"];
}

static NSDictionary *offShape(void)
{
    return @{@"enabled": @NO, @"recordingMode": @"off"};
}

- (void) setUp
{
    [super setUp];

    self.agent = [[NewRelicAgentInternal alloc] init];
    SessionReplayReporter *reporter = [[SessionReplayReporter alloc] initWithApplicationToken:@"test-token"
                                                                                          url:@"mobile-collector.newrelic.com"];
    self.manager = [[SessionReplayManager alloc] initWithReporter:reporter url:@"mobile-collector.newrelic.com"];
    [self.agent setValue:self.manager forKey:@"sessionReplay"];

    // Return whatever self.config holds when the agent asks, so a test can swap or nil it.
    __weak typeof(self) weakSelf = self;
    self.mockHarvestController = [OCMockObject mockForClass:[NRMAHarvestController class]];
    [[[[self.mockHarvestController stub] classMethod] andDo:^(NSInvocation *invocation) {
        NRMAHarvesterConfiguration *config = weakSelf.config;
        [invocation setReturnValue:&config];
    }] configuration];

    self.mockAgentInternal = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    [[[[self.mockAgentInternal stub] classMethod] andReturn:self.agent] sharedInstance];
}

- (void) tearDown
{
    [self.manager stop];
    [self.mockAgentInternal stopMocking];
    [self.mockHarvestController stopMocking];

    for (NSString *name in testRuleNames()) {
        [[NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_maskedClassNames] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_unmaskedClassNames] removeObject:name];
    }

    // Parsing a session_replay config enqueues SessionReplay/Config supportability metrics.
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue clear];

    [super tearDown];
}

// Pass nil for a connect response with no "configuration" object at all, which is the only
// shape the parser treats as having no session replay config.
- (NRMAHarvesterConfiguration *) configWithSessionReplayJSON:(NSString *)sessionReplayJSON
{
    NSString *configuration = sessionReplayJSON
        ? [NSString stringWithFormat:@",\"configuration\":{\"session_replay\":%@}", sessionReplayJSON]
        : @"";
    NSString *json = [NSString stringWithFormat:@"{\"data_token\":[1234,5678],\"account_id\":190%@}", configuration];
    NSError *error = nil;
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    XCTAssertNil(error, @"test payload must be valid JSON");
    return [[NRMAHarvesterConfiguration alloc] initWithDictionary:parsed];
}

#pragma mark - Off shape

- (void) testOffShapeWhenNoConfiguration
{
    self.config = nil;

    XCTAssertEqualObjects([self.agent sessionReplayConfiguration], offShape());
}

- (void) testOffShapeWhenConnectSentNoSessionReplayConfig
{
    self.config = [self configWithSessionReplayJSON:nil];
    XCTAssertFalse(self.config.has_session_replay_config);

    XCTAssertEqualObjects([self.agent sessionReplayConfiguration], offShape());
}

- (void) testOffShapeWhenDisabled
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":false}"];
    self.manager.sessionReplayMode = SessionReplayRecordingModeFull;

    XCTAssertEqualObjects([self.agent sessionReplayConfiguration], offShape());
}

- (void) testOffShapeWhenNoReplayManager
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true}"];
    [self.agent setValue:nil forKey:@"sessionReplay"];

    XCTAssertEqualObjects([self.agent sessionReplayConfiguration], offShape());
}

- (void) testPublicGetterReturnsOffShapeBeforeAgentStarts
{
    [self.mockAgentInternal stopMocking];
    self.mockAgentInternal = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    [[[[self.mockAgentInternal stub] classMethod] andReturn:nil] sharedInstance];

    XCTAssertEqualObjects([NewRelic sessionReplayConfiguration], offShape());
}

#pragma mark - Resolved configuration

- (void) testEnabledConfigurationReportsAllKeys
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true,\"mode\":\"custom\","
                   "\"mask_application_text\":false,\"mask_user_input_text\":true,"
                   "\"mask_all_images\":false,\"mask_all_user_touches\":true}"];
    self.manager.sessionReplayMode = SessionReplayRecordingModeFull;

    NSDictionary *result = [self.agent sessionReplayConfiguration];

    NSSet *expectedKeys = [NSSet setWithArray:@[@"enabled", @"mode", @"recordingMode",
                                                @"maskApplicationText", @"maskUserInputText", @"maskAllImages", @"maskAllUserTouches",
                                                @"maskedClasses", @"unmaskedClasses", @"maskedKeys", @"unmaskedKeys"]];
    XCTAssertEqualObjects([NSSet setWithArray:result.allKeys], expectedKeys);
    XCTAssertEqualObjects(result[@"enabled"], @YES);
    XCTAssertEqualObjects(result[@"mode"], @"custom");
    XCTAssertEqualObjects(result[@"recordingMode"], @"full");
    XCTAssertEqualObjects(result[@"maskApplicationText"], @NO);
    XCTAssertEqualObjects(result[@"maskUserInputText"], @YES);
    XCTAssertEqualObjects(result[@"maskAllImages"], @NO);
    XCTAssertEqualObjects(result[@"maskAllUserTouches"], @YES);
}

- (void) testRecordingModeStrings
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true}"];

    self.manager.sessionReplayMode = SessionReplayRecordingModeError;
    XCTAssertEqualObjects([self.agent sessionReplayConfiguration][@"recordingMode"], @"error");

    self.manager.sessionReplayMode = SessionReplayRecordingModeOff;
    XCTAssertEqualObjects([self.agent sessionReplayConfiguration][@"recordingMode"], @"off");
}

- (void) testListsMergeLocalRulesAndCustomRules
{
    [[NRMAAgentConfiguration local_session_replay_maskedClassNames] addObject:@"LocalSecretView"];
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true,\"mode\":\"custom\",\"custom_masking_rules\":["
                   "{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"RemoteSecretView\"],\"identifier\":\"class\"},"
                   "{\"type\":\"unmask\",\"operator\":\"equals\",\"name\":[\"RemotePublicView\"],\"identifier\":\"class\"},"
                   "{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"remote-private\"],\"identifier\":\"accessibilityIdentifier\"},"
                   "{\"type\":\"unmask\",\"operator\":\"equals\",\"name\":[\"remote-public\"],\"identifier\":\"accessibilityIdentifier\"}]}"];

    NSDictionary *result = [self.agent sessionReplayConfiguration];

    XCTAssertTrue([result[@"maskedClasses"] containsObject:@"LocalSecretView"]);
    XCTAssertTrue([result[@"maskedClasses"] containsObject:@"RemoteSecretView"]);
    XCTAssertTrue([result[@"unmaskedClasses"] containsObject:@"RemotePublicView"]);
    XCTAssertTrue([result[@"maskedKeys"] containsObject:@"remote-private"]);
    XCTAssertTrue([result[@"unmaskedKeys"] containsObject:@"remote-public"]);
}

- (void) testListsAreImmutableSnapshots
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true,\"mode\":\"custom\"}"];

    NSDictionary *result = [self.agent sessionReplayConfiguration];
    XCTAssertFalse([result[@"maskedClasses"] isKindOfClass:[NSMutableArray class]]);

    [self.config addMaskedClassNames:@[@"AddedLater"]];

    XCTAssertFalse([result[@"maskedClasses"] containsObject:@"AddedLater"]);
}

@end
