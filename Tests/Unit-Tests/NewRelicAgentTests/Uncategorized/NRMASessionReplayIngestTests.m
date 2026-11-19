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

@interface NRMASessionReplayIngestTests : XCTestCase
@property id mockHarvestController;
@property id mockAgentInternal;
@property NewRelicAgentInternal *agent;
@property SessionReplayReporter *reporter;
@property SessionReplayManager *manager;
@property NRMAHarvesterConfiguration *config;
@end

@implementation NRMASessionReplayIngestTests

static NSString *const batch = @"[{\"type\":4,\"timestamp\":1,\"data\":{}}]";

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
    self.manager.externalCaptureSource = YES;
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
    [self.manager clearAllData];
    [[NSFileManager defaultManager] removeItemAtPath:errorModeMarkerPath() error:nil];
    // Leave the platform native for later tests, even when a test stops early.
    [NewRelic setPlatform:NRMAPlatform_Native];
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

- (NSString *) ingest:(NSString *)json
{
    return [self.agent recordSessionReplayEvents:json];
}

// Replaces the sharedInstance stub, so a test can act before the agent starts (nil) or after.
- (void) stubSharedInstance:(NewRelicAgentInternal *)agent
{
    [self.mockAgentInternal stopMocking];
    self.mockAgentInternal = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    [[[[self.mockAgentInternal stub] classMethod] andReturn:agent] sharedInstance];
}

#pragma mark - Upload URL

// Storing events writes the crash-recovery URL file, built by the same call as the harvest's upload URL.
// A plain-init agent has no session id, so the events are filed under the manager's fallback.
- (NSString *) externalURLFileAttributes
{
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *urlFile = [[documents stringByAppendingPathComponent:kNRMA_SessionReplayFrames_folder]
                         stringByAppendingPathComponent:@"unknown_session_upload_url.txt"];
    NSString *url = [NSString stringWithContentsOfFile:urlFile encoding:NSUTF8StringEncoding error:nil];
    return url == nil ? nil : uploadAttributes([NSURL URLWithString:url]);
}

- (void) testExternalUploadsCarryTheAgentRRWebVersion
{
    [self useFullSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
    NRMADrainReplayQueue(self.manager);
    XCTAssertTrue([[self externalURLFileAttributes] containsString:@"rrweb.version=^2.0.0-alpha.17"]);
}

- (void) testExternalUploadURLSaysWhenItHoldsNoMeta
{
    // This test harvests, so its uploads go to a host that never resolves.
    self.reporter = [[SessionReplayReporter alloc] initWithApplicationToken:@"test-token" url:@"test.invalid"];
    self.manager = [[SessionReplayManager alloc] initWithReporter:self.reporter url:@"test.invalid"];
    self.manager.externalCaptureSource = YES;
    [self.agent setValue:self.manager forKey:@"sessionReplay"];
    [self useFullSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
    NRMADrainReplayQueue(self.manager);
    XCTAssertTrue([[self externalURLFileAttributes] containsString:@"hasMeta=true"]);
    [self.manager harvest];
    XCTAssertEqualObjects([self ingest:@"[{\"type\":3,\"timestamp\":2,\"data\":{}}]"], kNRSessionReplayIngestAccepted);
    NRMADrainReplayQueue(self.manager);
    XCTAssertTrue([[self externalURLFileAttributes] containsString:@"hasMeta=false"]);
}

// Guard: passes before and after the change.
- (void) testNativeUploadURLKeepsTheNativeRRWebVersion
{
    [self useFullSampling];
    NSURL *url = [self.manager generateUploadURLWithUncompressedDataSize:10 firstTimestamp:1000 lastTimestamp:2000
                                                            isFirstChunk:YES isGZipped:YES];
    XCTAssertTrue([uploadAttributes(url) containsString:@"rrweb.version=^2.0.0-alpha.17"]);
    XCTAssertTrue([uploadAttributes(url) containsString:@"hasMeta=true"]);
}

#pragma mark - Ingest gate

- (void) testAcceptedWhenRecordingInFull
{
    [self useFullSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
}

- (void) testDroppedDisabledWhenNativeCaptureIsNotSuppressed
{
    self.manager.externalCaptureSource = NO;
    [self useFullSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);
}

- (void) testDroppedDisabledWhenReplayIsOff
{
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);          // no config
    [self useFullSampling];
    self.config.session_replay_enabled = NO;
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);          // disabled
    [self useOffSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);          // sampled off
}

- (void) testDroppedDisabledWhilePausedAndAfterSessionEnd
{
    [self useFullSampling];
    [self startSession];
    XCTAssertTrue([self.agent pauseReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);
    XCTAssertTrue([self.agent recordReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
    [self.agent sessionReplayEndSession];
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);
}

- (void) testErrorModeIsDroppedUntilAnErrorSwitchesToFull
{
    [self useErrorSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestDroppedDisabled);
    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
}

- (void) testAcceptedAfterRecordReplayInAnUnsampledSession
{
    [self useOffSampling];
    [self startSession];
    XCTAssertTrue([self.agent recordReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self ingest:batch], kNRSessionReplayIngestAccepted);
}

- (void) testDroppedInvalidForEmptyEvents
{
    [self useFullSampling];
    [self startSession];
    XCTAssertEqualObjects([self ingest:@""], kNRSessionReplayIngestDroppedInvalid);
}

- (void) testLargeBatchesAreAccepted
{
    [self useFullSampling];
    [self startSession];
    NSString *euros = [@"" stringByPaddingToLength:333334 withString:@"€" startingAtIndex:0];   // 1,000,002 bytes of UTF-8
    XCTAssertEqualObjects([self ingest:euros], kNRSessionReplayIngestAccepted);
}

// Guard: passes before and after the change.
- (void) testDroppedInvalidWhenNotEncodableAsUTF8
{
    [self useFullSampling];
    [self startSession];
    unichar lone = 0xD800;   // an unpaired surrogate
    XCTAssertEqualObjects([self ingest:[NSString stringWithCharacters:&lone length:1]], kNRSessionReplayIngestDroppedInvalid);
}

- (void) testPublicEntryBeforeTheAgentStartsIsDroppedDisabled
{
    [self stubSharedInstance:nil];
    XCTAssertEqualObjects([NewRelic recordSessionReplayEvents:batch], kNRSessionReplayIngestDroppedDisabled);
}

- (void) testOnlyTheFlutterPlatformSuppressesNativeCapture
{
    for (NRMAApplicationPlatform platform = NRMAPlatform_Native; platform <= NRMAPlatform_Unreal; platform++) {
        [NewRelic setPlatform:platform];
        XCTAssertEqual([NewRelicAgentInternal sessionReplayExternalCaptureSource], (BOOL)(platform == NRMAPlatform_Flutter),
                       @"platform %lu", (unsigned long)platform);
    }
}

@end
