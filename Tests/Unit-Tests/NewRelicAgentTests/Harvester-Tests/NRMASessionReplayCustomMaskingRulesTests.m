//
//  NRMASessionReplayCustomMaskingRulesTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Coverage for parsing session replay custom masking rules out of the connect response.
//
//  The connect endpoint sends accessibility identifier rules to iOS apps with
//  "identifier": "accessibilityIdentifier" (Android apps get "tag"). The agent only
//  recognized "tag", so every accessibility identifier rule set in Application Settings
//  was silently dropped on iOS.
//

#import <XCTest/XCTest.h>
#import "NRMAHarvesterConfiguration.h"
#import "NRMAAgentConfiguration.h"
#import "NRAgentTestBase.h"
#import "NRMASupportMetricHelper.h"
#import "NRMATaskQueue.h"

@interface NRMATaskQueue (tests)
+ (void) clear;
@end

@interface NRMASessionReplayCustomMaskingRulesTests : NRMAAgentTestBase
@end

@implementation NRMASessionReplayCustomMaskingRulesTests

// The parsed lists are backed by process-wide arrays in NRMAAgentConfiguration, so every
// name a test adds must be removed again or it leaks into later tests.
static NSArray<NSString *> *testRuleNames(void)
{
    return @[@"private", @"public", @"legacy-tag", @"SecretLabel", @"PublicLabel", @"stored-private"];
}

- (void) tearDown
{
    for (NSString *name in testRuleNames()) {
        [[NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_maskedClassNames] removeObject:name];
        [[NRMAAgentConfiguration local_session_replay_unmaskedClassNames] removeObject:name];
    }

    // Parsing a session_replay config enqueues SessionReplay/Config supportability metrics.
    // Left queued, they are what the next test reading "the next recorded metric" gets
    // (NRMAStartTimerTests, NRMASupportMetricHelperTests).
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue clear];

    [super tearDown];
}

- (NRMAHarvesterConfiguration *) configurationWithRulesJSON:(NSString *)rulesJSON
{
    NSString *json = [NSString stringWithFormat:@"{"
                      "\"data_token\":[1234,5678],"
                      "\"account_id\":190,"
                      "\"configuration\":{\"session_replay\":{\"enabled\":true,\"mode\":\"custom\","
                          "\"custom_masking_rules\":%@"
                      "}}"
                      "}", rulesJSON];
    NSError *error = nil;
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    XCTAssertNil(error, @"test payload must be valid JSON");
    return [[NRMAHarvesterConfiguration alloc] initWithDictionary:parsed];
}

#pragma mark - Identifier values

// The exact rule shape the staging connect endpoint returns for an iOS app.
- (void) testAccessibilityIdentifierMaskRuleIsApplied
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"private\"],\"identifier\":\"accessibilityIdentifier\"}]"];

    XCTAssertTrue([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
    XCTAssertFalse([configuration.session_replay_unmaskedAccessibilityIdentifiers containsObject:@"private"]);
}

- (void) testAccessibilityIdentifierUnmaskRuleIsApplied
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"unmask\",\"operator\":\"equals\",\"name\":[\"public\"],\"identifier\":\"accessibilityIdentifier\"}]"];

    XCTAssertTrue([configuration.session_replay_unmaskedAccessibilityIdentifiers containsObject:@"public"]);
    XCTAssertFalse([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"public"]);
}

// "tag" is what Android apps receive; keep accepting it on iOS too.
- (void) testTagRuleIsStillApplied
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"legacy-tag\"],\"identifier\":\"tag\"}]"];

    XCTAssertTrue([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"legacy-tag"]);
}

- (void) testClassRulesAreApplied
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"SecretLabel\"],\"identifier\":\"class\"},"
         "{\"type\":\"unmask\",\"operator\":\"equals\",\"name\":[\"PublicLabel\"],\"identifier\":\"class\"}]"];

    XCTAssertTrue([configuration.session_replay_maskedClassNames containsObject:@"SecretLabel"]);
    XCTAssertTrue([configuration.session_replay_unmaskedClassNames containsObject:@"PublicLabel"]);
}

// Masking wins over unmasking when a view matches both, but that is decided at capture time
// (ViewDetails), so the parser has to keep the identifier in both lists.
- (void) testIdentifierInBothMaskAndUnmaskRulesIsKeptInBothLists
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"unmask\",\"operator\":\"equals\",\"name\":[\"private\"],\"identifier\":\"accessibilityIdentifier\"},"
         "{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"private\"],\"identifier\":\"accessibilityIdentifier\"}]"];

    XCTAssertTrue([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
    XCTAssertTrue([configuration.session_replay_unmaskedAccessibilityIdentifiers containsObject:@"private"]);
}

// The stored configuration is re-parsed through -initWithDictionary: on the next launch,
// so the rule has to survive the asDictionary round trip with its original identifier.
- (void) testAccessibilityIdentifierRuleSurvivesStoredConfigurationRoundTrip
{
    NRMAHarvesterConfiguration *source = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"stored-private\"],\"identifier\":\"accessibilityIdentifier\"}]"];
    [[NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers] removeObject:@"stored-private"];

    NRMAHarvesterConfiguration *restored = [[NRMAHarvesterConfiguration alloc] initWithDictionary:[source asDictionary]];

    XCTAssertTrue([restored.session_replay_maskedAccessibilityIdentifiers containsObject:@"stored-private"]);
}

#pragma mark - Malformed rules

- (void) testUnknownIdentifierIsIgnored
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"private\"],\"identifier\":\"testID\"}]"];

    XCTAssertFalse([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
    XCTAssertFalse([configuration.session_replay_maskedClassNames containsObject:@"private"]);
}

// name has always been an array, but a string here used to be sent -count and crash the
// connect parse.
- (void) testNonArrayNameDoesNotCrashAndIsIgnored
{
    NRMAHarvesterConfiguration *configuration = nil;
    XCTAssertNoThrow(configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":\"private\",\"identifier\":\"accessibilityIdentifier\"}]"]);

    XCTAssertFalse([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
}

- (void) testNonStringNamesAreSkipped
{
    NRMAHarvesterConfiguration *configuration = nil;
    XCTAssertNoThrow(configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[42,\"private\",null],\"identifier\":\"accessibilityIdentifier\"}]"]);

    XCTAssertTrue([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
    XCTAssertFalse([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@42]);
    XCTAssertFalse([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:[NSNull null]]);
}

- (void) testNonDictionaryRuleEntriesAreSkipped
{
    NRMAHarvesterConfiguration *configuration = nil;
    XCTAssertNoThrow(configuration = [self configurationWithRulesJSON:
        @"[\"oops\",42,{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"private\"],\"identifier\":\"accessibilityIdentifier\"}]"]);

    XCTAssertTrue([configuration.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
    XCTAssertEqual(configuration.session_replay_customRules.count, 1u);
}

// -[NRMAHarvester configureFromCollector:] writes -asDictionary to NSUserDefaults, which aborts
// on non-property-list values. Malformed values from the connect response must not reach it.
- (void) testMalformedRulesDoNotBreakConfigurationPersistence
{
    NRMAHarvesterConfiguration *configuration = [self configurationWithRulesJSON:
        @"[{\"type\":\"mask\",\"operator\":null,\"name\":[42,\"private\",null],\"identifier\":\"accessibilityIdentifier\"},"
         "{\"type\":\"mask\",\"operator\":\"equals\",\"name\":[\"public\"],\"identifier\":null},"
         "{\"type\":null,\"operator\":\"equals\",\"name\":[\"public\"],\"identifier\":\"class\"},"
         "{\"type\":\"mask\",\"operator\":\"equals\",\"name\":\"public\",\"identifier\":\"accessibilityIdentifier\"}]"];

    XCTAssertEqual(configuration.session_replay_customRules.count, 1u, @"only the applied rule is kept");
    SessionReplayCustomMaskingRule *rule = configuration.session_replay_customRules.firstObject;
    XCTAssertEqualObjects(rule.name, (@[@"private"]));
    XCTAssertNil(rule.operatorName);

    NSDictionary *stored = [configuration asDictionary];
    XCTAssertTrue([NSPropertyListSerialization propertyList:stored isValidForFormat:NSPropertyListBinaryFormat_v1_0],
                  @"the persisted configuration must be a valid property list");

    NSString *key = @"com.newrelic.tests.sessionReplayCustomMaskingRules";
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:key];
    id restoredDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    XCTAssertTrue([restoredDictionary isKindOfClass:[NSDictionary class]]);

    [[NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers] removeObject:@"private"];
    NRMAHarvesterConfiguration *restored = [[NRMAHarvesterConfiguration alloc] initWithDictionary:restoredDictionary];
    XCTAssertTrue([restored.session_replay_maskedAccessibilityIdentifiers containsObject:@"private"]);
}

@end
