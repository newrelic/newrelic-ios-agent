//
//  NRMAHarvesterConfigurationLifetimeTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Regression coverage for the crash reported at -[NRMAHarvester transitionToConnected:].
//
//  NRMAHarvesterConfiguration used to declare its object-typed properties as `assign`,
//  which under ARC means unsafe_unretained: the setter stored a raw pointer into the
//  autoreleased dictionary it was parsed from. The configuration object itself is held
//  in a strong ivar that long outlives that pool, so once the pool drained every read of
//  encoding_key / request_header_map / log_reporting_level / session_replay_mode was a
//  use-after-free, surfacing as SIGSEGV inside objc_msgSend.
//
//  Each test below parses inside an explicit @autoreleasepool and reads only after the
//  pool has drained. Run with NSZombieEnabled=YES (or MallocScribble=1) to make a
//  regression abort loudly instead of silently reading recycled memory.
//

#import <XCTest/XCTest.h>
#import "NRMAHarvesterConfiguration.h"
#import "NRAgentTestBase.h"

@interface NRMAHarvesterConfigurationLifetimeTests : NRMAAgentTestBase
@end

@implementation NRMAHarvesterConfigurationLifetimeTests

// Builds the config from a freshly parsed JSON graph, mirroring
// -[NRMAHarvester configureFromCollector:]. Every string here is heap allocated by
// NSJSONSerialization rather than being a compile-time constant, so it is genuinely
// deallocated when the pool drains -- a literal would mask the bug.
- (NRMAHarvesterConfiguration *) configurationFromJSON:(NSString *)json
{
    NRMAHarvesterConfiguration *configuration = nil;

    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:&error];
        XCTAssertNil(error, @"test payload must be valid JSON");
        XCTAssertNotNil(parsed);

        configuration = [[NRMAHarvesterConfiguration alloc] initWithDictionary:parsed];
    }

    return configuration;
}

- (NSString *) fullCollectorPayload
{
    return @"{"
            "\"application_token\":\"AA1234567890abcdef\","
            "\"data_token\":[1234,5678],"
            "\"account_id\":190,"
            "\"cross_process_id\":\"12345#67890\","
            "\"encoding_key\":\"d67afc830dab717fd163bfcb0b8b88423e9a1a3b\","
            "\"entity_guid\":\"MTAxfEFQTXxBUFB8MQ\","
            "\"trusted_account_key\":\"190\","
            "\"request_headers_map\":{\"X-Trace-Id\":\"abc123\",\"X-Tenant\":\"au\"},"
            "\"configuration\":{"
                "\"logs\":{\"enabled\":true,\"level\":\"DEBUG\",\"sampling_rate\":100},"
                "\"session_replay\":{\"enabled\":true,\"mode\":\"custom\",\"sampling_rate\":50,\"error_sampling_rate\":25}"
            "}"
            "}";
}

#pragma mark - Lifetime

// The core regression test: the exact read that crashed, performed after the pool drain.
- (void) testCollectorConfigurationOutlivesItsParseDictionary
{
    NRMAHarvesterConfiguration *configuration = [self configurationFromJSON:[self fullCollectorPayload]];
    XCTAssertNotNil(configuration);

    // -[NRMAHarvester configureHarvester:] reads request_header_map here.
    XCTAssertEqualObjects(configuration.request_header_map[@"X-Trace-Id"], @"abc123");
    XCTAssertEqualObjects(configuration.request_header_map[@"X-Tenant"], @"au");
    XCTAssertEqual(configuration.request_header_map.count, 2u);

    // -[NRMAHarvester connected] reads log_reporting_level on every harvest cycle.
    XCTAssertEqualObjects(configuration.log_reporting_level, @"DEBUG");

    // ViewDetails.swift reads session_replay_mode on every captured view.
    XCTAssertEqualObjects(configuration.session_replay_mode, @"custom");

    XCTAssertEqualObjects(configuration.encoding_key, @"d67afc830dab717fd163bfcb0b8b88423e9a1a3b");
}

// The stored-configuration path: NSUserDefaults hands back an autoreleased graph, and the
// config built from it is retained across harvest cycles by -[NRMAHarvester init].
- (void) testStoredConfigurationOutlivesItsUserDefaultsDictionary
{
    NSString *key = @"com.newrelic.tests.harvesterConfigurationLifetime";
    NRMAHarvesterConfiguration *configuration = nil;

    @autoreleasepool {
        NRMAHarvesterConfiguration *source = [self configurationFromJSON:[self fullCollectorPayload]];
        [[NSUserDefaults standardUserDefaults] setObject:[source asDictionary] forKey:key];
    }

    @autoreleasepool {
        id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        XCTAssertTrue([stored isKindOfClass:[NSDictionary class]]);
        configuration = [[NRMAHarvesterConfiguration alloc] initWithDictionary:(NSDictionary *)stored];
    }

    XCTAssertEqualObjects(configuration.request_header_map[@"X-Trace-Id"], @"abc123");
    XCTAssertEqualObjects(configuration.log_reporting_level, @"DEBUG");
    XCTAssertEqualObjects(configuration.session_replay_mode, @"custom");
    XCTAssertEqualObjects(configuration.encoding_key, @"d67afc830dab717fd163bfcb0b8b88423e9a1a3b");

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

// SessionReplayCustomMaskingRule had the same four unretained properties, and its rules
// are held for the whole session in session_replay_customRules.
- (void) testCustomMaskingRulesOutliveTheirParseDictionary
{
    NRMAHarvesterConfiguration *configuration = [self configurationFromJSON:
        @"{"
         "\"data_token\":[1234,5678],"
         "\"account_id\":190,"
         "\"configuration\":{\"session_replay\":{\"enabled\":true,\"mode\":\"custom\","
             "\"custom_masking_rules\":["
                 "{\"identifier\":\"tag\",\"name\":[\"password_field\"],\"operator\":\"equals\",\"type\":\"mask\"}"
             "]}}"
         "}"];
    XCTAssertNotNil(configuration);

    XCTAssertEqual(configuration.session_replay_customRules.count, 1u);
    SessionReplayCustomMaskingRule *rule = configuration.session_replay_customRules.firstObject;
    XCTAssertNotNil(rule);

    XCTAssertEqualObjects(rule.identifier, @"tag");
    XCTAssertEqualObjects(rule.type, @"mask");
    XCTAssertEqualObjects(rule.operatorName, @"equals");
    XCTAssertEqualObjects(rule.name, (@[@"password_field"]));
}

// A `copy` property must snapshot, not alias: mutating the caller's container afterwards
// must not change what the configuration reports.
- (void) testRequestHeaderMapIsSnapshotNotAliased
{
    NRMAHarvesterConfiguration *configuration = [[NRMAHarvesterConfiguration alloc] init];

    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithObject:@"abc123" forKey:@"X-Trace-Id"];
    configuration.request_header_map = headers;
    [headers setObject:@"leaked" forKey:@"X-Added-Later"];

    XCTAssertEqual(configuration.request_header_map.count, 1u);
    XCTAssertNil(configuration.request_header_map[@"X-Added-Later"]);
}

#pragma mark - Comparison correctness

// request_header_map equality was a raw pointer comparison, so two configurations
// carrying identical headers compared unequal and forced needless reconnects.
- (void) testConfigurationsWithEqualHeaderMapsAreEqual
{
    NRMAHarvesterConfiguration *a = [self configurationFromJSON:[self fullCollectorPayload]];
    NRMAHarvesterConfiguration *b = [self configurationFromJSON:[self fullCollectorPayload]];

    XCTAssertNotEqual(a.request_header_map, b.request_header_map, @"must be distinct objects for this test to mean anything");
    XCTAssertEqualObjects(a, b);
    XCTAssertEqual(a.hash, b.hash);
}

// NOTE: a separate, unfixed defect lives next to this one. In -initWithDictionary: the
// default-masking override is gated on `self.session_replay_mode == SessionReplayMaskingModeDefault`,
// a raw pointer comparison. SessionReplayMaskingModeDefault is a `static const` in a header,
// so each Mach-O image gets its own @"default" instance, and a collector-supplied "default"
// is a freshly parsed string either way -- the comparison is therefore never true in practice
// and the documented default masking booleans never apply. It is deliberately NOT fixed here:
// the override forces session_replay_maskAllUserTouches to NO, so correcting the comparison
// would *reduce* masking and unmask user touches that are masked today. That needs product
// review on its own, not a ride-along with a crash fix.

@end
