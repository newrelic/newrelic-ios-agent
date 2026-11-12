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
#import "NRMASupportMetricHelper.h"
#import "NRMATaskQueue.h"
#import "Constants.h"
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

static NSDictionary *offShape(void)
{
    return @{@"enabled": @NO, @"recordingMode": @"off"};
}

// isManuallyActive runs a sessionReplayQueue.sync, so returning from it means every block
// queued before it has run. Used as a barrier for the manager's async mode changes.
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
    [[NSFileManager defaultManager] removeItemAtPath:errorModeMarkerPath() error:nil];
    [self.mockAgentInternal stopMocking];
    [self.mockHarvestController stopMocking];

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

- (NSString *) recordingMode
{
    return [self.agent sessionReplayConfiguration][@"recordingMode"];
}

// Lets queued work finish and any already-queued post reach the main run loop, so it can't
// be mistaken for a post caused by what the test does next.
- (void) settle
{
    NRMADrainReplayQueue(self.manager);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

- (XCTestExpectation *) expectNoConfigurationPost
{
    [self settle];
    XCTestExpectation *expectation = [self expectationForNotification:kNRSessionReplayConfigurationDidChangeNotification
                                                               object:nil
                                                              handler:nil];
    expectation.inverted = YES;
    return expectation;
}

// Waits for the next post and returns its userInfo, checked against the getter at delivery.
- (NSDictionary *) waitForConfigurationPostAfter:(void (^)(void))action
{
    __block NSDictionary *userInfo = nil;
    XCTestExpectation *expectation = [self expectationForNotification:kNRSessionReplayConfigurationDidChangeNotification
                                                               object:nil
                                                              handler:^BOOL(NSNotification *note) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(note.userInfo, [self.agent sessionReplayConfiguration]);
        userInfo = note.userInfo;
        return YES;
    }];
    action();
    [self waitForExpectations:@[expectation] timeout:2.0];
    return userInfo;
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
                                                @"maskApplicationText", @"maskUserInputText", @"maskAllImages", @"maskAllUserTouches"]];
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

#pragma mark - Recording mode

- (void) testErrorSampledSessionReportsError
{
    [self useErrorSampling];
    [self startSession];

    XCTAssertEqualObjects([self recordingMode], @"error");
}

- (void) testFullSampledSessionReportsFull
{
    [self useFullSampling];
    [self startSession];

    XCTAssertEqualObjects([self recordingMode], @"full");
}

- (void) testErrorThenErrorEventReportsFull
{
    [self useErrorSampling];
    [self startSession];

    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);

    XCTAssertEqualObjects([self recordingMode], @"full");
}

- (void) testPauseReportsOffAndErrorKeepsItPaused
{
    [self useFullSampling];
    [self startSession];

    XCTAssertTrue([self.agent pauseReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"off");

    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"off");
}

- (void) testPauseInErrorModeReportsOffAndErrorKeepsItPaused
{
    [self useErrorSampling];
    [self startSession];

    XCTAssertTrue([self.agent pauseReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"off");

    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"off");
}

- (void) testRecordAfterPauseReportsFull
{
    [self useFullSampling];
    [self startSession];
    XCTAssertTrue([self.agent pauseReplay]);
    NRMADrainReplayQueue(self.manager);

    XCTAssertTrue([self.agent recordReplay]);
    NRMADrainReplayQueue(self.manager);

    XCTAssertEqualObjects([self recordingMode], @"full");
}

- (void) testSessionEndReportsOff
{
    [self useFullSampling];
    [self startSession];

    [self.agent sessionReplayEndSession];
    NRMADrainReplayQueue(self.manager);

    XCTAssertEqualObjects([self recordingMode], @"off");
}

- (void) testStoppedSessionStartSampledOffReportsOff
{
    [self useFullSampling];
    [self startSession];
    [self.manager stop];

    [self useOffSampling];
    [self startSession];

    XCTAssertEqualObjects([self recordingMode], @"off");
}

- (void) testReconnectSampledOffWhileRecordingKeepsRunningMode
{
    [self useOffSampling];
    [self startSession];
    XCTAssertTrue([self.agent recordReplay]);
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"full");

    // A mid-session reconnect runs the config path again with the same off-sampled seeds.
    [self startSession];

    XCTAssertEqualObjects([self recordingMode], @"full");
    XCTAssertTrue([self.manager isRunning]);
}

- (void) testDisabledAfterRunningLeavesModeOff
{
    [self useFullSampling];
    [self startSession];

    self.config.session_replay_enabled = NO;
    [self.agent sessionReplayDisabled];
    NRMADrainReplayQueue(self.manager);

    XCTAssertEqual(self.manager.sessionReplayMode, SessionReplayRecordingModeOff);
}

- (void) testErrorAfterErrorSessionEndedStaysOffAndKeepsMarker
{
    [self useErrorSampling];
    [self startSession];
    NSString *marker = errorModeMarkerPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:[marker stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue([[NSFileManager defaultManager] createFileAtPath:marker contents:[NSData data] attributes:nil]);

    [self.agent sessionReplayEndSession];
    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);

    XCTAssertEqualObjects([self recordingMode], @"off");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:marker],
                  @"an error after the session ended must not clear the error-mode marker");
}

- (void) testGetterIsSafeFromBackgroundThreadsDuringModeChanges
{
    [self useFullSampling];
    [self startSession];

    NSSet *validModes = [NSSet setWithArray:@[@"off", @"error", @"full"]];
    __block NSUInteger invalidResults = 0;
    NSObject *lock = [NSObject new];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        dispatch_apply(200, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
            NSString *mode = [self.agent sessionReplayConfiguration][@"recordingMode"];
            if (![validModes containsObject:mode]) {
                @synchronized(lock) { invalidResults++; }
            }
        });
    });

    for (int i = 0; i < 20; i++) {
        [self.agent pauseReplay];
        [self.agent recordReplay];
    }

    XCTAssertEqual(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    XCTAssertEqual(invalidResults, (NSUInteger)0);
}

#pragma mark - Change notification

- (void) testErrorSwitchPostsFullOnMainThread
{
    [self useErrorSampling];
    [self startSession];
    [self settle];

    NSDictionary *userInfo = [self waitForConfigurationPostAfter:^{
        [self.agent sessionReplayOnError:nil];
    }];

    XCTAssertEqualObjects(userInfo[@"recordingMode"], @"full");
}

- (void) testPausePostsOff
{
    [self useFullSampling];
    [self startSession];
    [self settle];

    NSDictionary *userInfo = [self waitForConfigurationPostAfter:^{
        XCTAssertTrue([self.agent pauseReplay]);
    }];

    XCTAssertEqualObjects(userInfo[@"recordingMode"], @"off");
}

- (void) testRecordPostsFull
{
    [self useFullSampling];
    [self startSession];
    [self settle];
    [self waitForConfigurationPostAfter:^{
        XCTAssertTrue([self.agent pauseReplay]);
    }];

    NSDictionary *userInfo = [self waitForConfigurationPostAfter:^{
        XCTAssertTrue([self.agent recordReplay]);
    }];

    XCTAssertEqualObjects(userInfo[@"recordingMode"], @"full");
}

- (void) testNoPostWhenPauseOrRecordReturnsNo
{
    [self useFullSampling];
    XCTestExpectation *noPost = [self expectNoConfigurationPost];

    XCTAssertFalse([self.agent pauseReplay], @"nothing is recording yet");

    [self startSession];
    XCTAssertFalse([self.agent recordReplay], @"already recording in full");

    [self.manager stop];
    [self useErrorSampling];
    [self startSession];
    XCTAssertFalse([self.agent recordReplay], @"error mode is already recording");
    NRMADrainReplayQueue(self.manager);
    XCTAssertEqualObjects([self recordingMode], @"error");

    [self waitForExpectations:@[noPost] timeout:0.5];
}

- (void) testNoPostOnErrorWhilePausedOrFull
{
    [self useFullSampling];
    [self startSession];
    XCTestExpectation *noPostWhileFull = [self expectNoConfigurationPost];
    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);
    [self waitForExpectations:@[noPostWhileFull] timeout:0.5];

    XCTAssertTrue([self.agent pauseReplay]);
    XCTestExpectation *noPostWhilePaused = [self expectNoConfigurationPost];
    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);
    [self waitForExpectations:@[noPostWhilePaused] timeout:0.5];
}

- (void) testNoPostAtSessionEndOrForErrorAfterIt
{
    [self useErrorSampling];
    [self startSession];
    XCTestExpectation *noPost = [self expectNoConfigurationPost];

    [self.agent sessionReplayEndSession];
    [self.agent sessionReplayOnError:nil];
    NRMADrainReplayQueue(self.manager);

    [self waitForExpectations:@[noPost] timeout:0.5];
}

- (void) testHandlerCanRecordFromInsideNotification
{
    [self useFullSampling];
    [self startSession];
    [self settle];

    NSMutableArray<NSString *> *modes = [NSMutableArray array];
    XCTestExpectation *twoPosts = [self expectationForNotification:kNRSessionReplayConfigurationDidChangeNotification
                                                            object:nil
                                                           handler:^BOOL(NSNotification *note) {
        [modes addObject:note.userInfo[@"recordingMode"]];
        if (modes.count == 1) {
            XCTAssertTrue([self.agent recordReplay]);
        }
        return YES;
    }];
    twoPosts.expectedFulfillmentCount = 2;

    XCTAssertTrue([self.agent pauseReplay]);
    [self waitForExpectations:@[twoPosts] timeout:2.0];

    XCTAssertEqualObjects(modes, (@[@"off", @"full"]));
}

@end
