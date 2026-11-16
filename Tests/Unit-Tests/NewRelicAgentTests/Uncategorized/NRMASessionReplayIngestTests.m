//
//  NRMASessionReplayIngestTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Coverage for taking rrweb events from an external replay source (the Flutter agent)
//  and uploading them with the native agent's own session replay.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NewRelic.h"
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConfiguration.h"
#import "NRMASupportMetricHelper.h"
#import "NRMATaskQueue.h"
#import "Constants.h"
#import <NewRelic/NewRelic-Swift.h>

@interface NRMATaskQueue (ingestTests)
+ (void) clear;
@end

@interface SessionReplayReporter (ingestTests)
- (NSURL *) uploadURLWithUncompressedDataSize:(NSInteger)size firstTimestamp:(NSTimeInterval)first
                                 lastTimestamp:(NSTimeInterval)last isFirstChunk:(BOOL)isFirstChunk
                                     isGZipped:(BOOL)isGZipped rrwebVersion:(NSString *)rrwebVersion;
@end

@interface NRMASessionReplayIngestTests : XCTestCase
@property id mockHarvestController;
@property id mockAgentInternal;
@property NewRelicAgentInternal *agent;
@property SessionReplayReporter *reporter;
@property SessionReplayManager *manager;
@property NRMAHarvesterConfiguration *config;
@end

@implementation NRMASessionReplayIngestTests

// isManuallyActive runs a sessionReplayQueue.sync, so returning from it means every block
// queued before it has run.
static void NRMADrainReplayQueue(SessionReplayManager *manager)
{
    (void)[manager isManuallyActive];
}

static NSString *errorModeMarkerPath(void)
{
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [[documents stringByAppendingPathComponent:kNRMA_SessionReplayFrames_folder]
            stringByAppendingPathComponent:kNRMA_SessionReplayErrorMode_marker];
}

static NSString *uploadAttributes(NSURL *url)
{
    for (NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].queryItems) {
        if ([item.name isEqualToString:@"attributes"]) { return item.value; }
    }
    return nil;
}

- (void) setUp
{
    [super setUp];

    self.agent = [[NewRelicAgentInternal alloc] init];
    self.reporter = [[SessionReplayReporter alloc] initWithApplicationToken:@"test-token"
                                                                        url:@"mobile-collector.newrelic.com"];
    self.manager = [[SessionReplayManager alloc] initWithReporter:self.reporter url:@"mobile-collector.newrelic.com"];
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
    [[NSFileManager defaultManager] removeItemAtPath:errorModeMarkerPath() error:nil];
    [self.mockAgentInternal stopMocking];
    [self.mockHarvestController stopMocking];

    // Parsing a session_replay config enqueues SessionReplay/Config supportability metrics.
    [NRMASupportMetricHelper processDeferredMetrics];
    [NRMATaskQueue clear];

    [super tearDown];
}

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

- (void) useFullSampling
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true}"];
    self.config.session_replay_sampling_rate = 100.0;
    self.config.session_replay_error_sampling_rate = 0.0;
    self.agent.sessionReplaySampleSeed = 1.0;
}

- (void) useErrorSampling
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true}"];
    self.config.session_replay_sampling_rate = 0.0;
    self.config.session_replay_error_sampling_rate = 100.0;
    self.agent.sessionReplaySampleSeed = 50.0;
    self.agent.sessionReplayErrorSampleSeed = 1.0;
}

- (void) useOffSampling
{
    self.config = [self configWithSessionReplayJSON:@"{\"enabled\":true}"];
    self.config.session_replay_sampling_rate = 0.0;
    self.config.session_replay_error_sampling_rate = 0.0;
    self.agent.sessionReplaySampleSeed = 50.0;
    self.agent.sessionReplayErrorSampleSeed = 50.0;
}

// Starts a session the way the config path does, then drains exactly once.
- (void) startSession
{
    [self.agent sessionReplayStart];
    NRMADrainReplayQueue(self.manager);
}

#pragma mark - Upload URL

- (void) testUploadURLStampsTheGivenRRWebVersion
{
    [self useFullSampling];
    NSURL *url = [self.reporter uploadURLWithUncompressedDataSize:10 firstTimestamp:1000 lastTimestamp:2000
                                                     isFirstChunk:YES isGZipped:YES rrwebVersion:@"2.1.0-flutter"];
    XCTAssertTrue([uploadAttributes(url) containsString:@"rrweb.version=2.1.0-flutter"]);
}

// Guard: passes before and after the change.
- (void) testNativeUploadURLKeepsTheNativeRRWebVersion
{
    [self useFullSampling];
    NSURL *url = [self.manager generateUploadURLWithUncompressedDataSize:10 firstTimestamp:1000 lastTimestamp:2000
                                                            isFirstChunk:YES isGZipped:YES];
    XCTAssertTrue([uploadAttributes(url) containsString:@"rrweb.version=^2.0.0-alpha.17"]);
}

@end
