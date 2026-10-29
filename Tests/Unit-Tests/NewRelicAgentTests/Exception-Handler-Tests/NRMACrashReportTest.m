//
//  NRMACrashReportTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/14/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NewRelicInternalUtils.h"
#import "NRMACrashReport.h"
#import "NRMACrashDataWriter.h"

 #import "NRMAExceptionDataCollectionWrapper.h"
 #import "PLCrashReport.h"
 #import "PLCrashReporter.h"

 #import "NRMAUncaughtExceptionHandler.h"
 #import "NRMAExceptionHandlerManager.h"
 #import "NRMAExceptionHandlerStartupManager.h"
 #import "NewRelicAgentInternal.h"
 #import "NRMACrashDataUploader.h"

 #import "NRMACrashReportFileManager.h"
 #import "NRMAFakeDataHelper.h"
 #import "NRMAFlags.h"
 #import "NRMAExceptionMetaDataStore.h"
 #import "NRMAExceptionhandlerConstants.h"
 #import "Constants.h"
 #import "NRMAJSON.h"
 #import <NewRelic/NewRelic-Swift.h>

 #if __has_include(<CrashReporter/CrashReporter.h>)
 #import <CrashReporter/CrashReporter.h>
 #import <CrashReporter/PLCrashReporter.h>
 #else
 #import "CrashReporter.h"
 #import "PLCrashReporter.h"
 #endif

@interface NRMACrashDataWriter ()
+ (NSString*) getOperatingDevice:(PLCrashReportOperatingSystem)osEnum;
+ (NSString*) getArchitectureFromProcessorInfo:(PLCrashReportProcessorInfo*)info;
+ (NSString*) getProcessorArchType:(PLCrashReportProcessorTypeEncoding)architecture;
@end


@interface NRMACrashReportTest : XCTestCase

@end

@implementation NRMACrashReportTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testOSName {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NRMACrashReport* report = [[NRMACrashReport alloc] initWithUUID:@"asdf"
                                                    buildIdentifier:@"blah"
                                                          timestamp:@1
                                                           appToken:@"token"
                                                          accountId:@213
                                                            agentId:@1123
                                                         deviceInfo:nil
                                                            appInfo:nil
                                                          exception:nil
                                                            threads:nil
                                                          libraries:nil
                                                    activityHistory:nil
                                                  sessionAttributes:nil
                                                    AnalyticsEvents:nil];

#if TARGET_OS_TV
    XCTAssertTrue([[report JSONObject][kNRMA_CR_platformKey] isEqualToString:NRMA_OSNAME_TVOS]);
#else
    XCTAssertTrue([[report JSONObject][kNRMA_CR_platformKey] isEqualToString:NRMA_OSNAME_IOS]);
#endif

}

- (void) testCrashReport {


    NRMACrashReport_DeviceInfo* deviceInfo = [[NRMACrashReport_DeviceInfo alloc] initWithMemoryUsage:@(1)
                                                                                         orientation:@(5)
                                                                                       networkStatus:@"WIFI"
                                                                                           diskUsage:@[]
                                                                                           osVersion:@"13"
                                                                                          deviceName:@"TestDevice"
                                                                                             osBuild:@"testOSBuild"
                                                                                        architecture:@"test_arch"
                                                                                         modelNumber:@"iphone@test"
                                                                                          deviceUuid:@"device_uuid"];

    NRMACrashReport_AppInfo* appInfo = [[NRMACrashReport_AppInfo alloc] initWithAppName:@"test_app"
                                                                         appVersion:@"testAppVersion"
                                                                               appBuild:@"testAppBuild"
                                                                               bundleId:@"com.test.bundleId"
                                                                            processPath:@"test/path"
                                                                            processName:@"test_process_name"
                                                                              processId:@(1)
                                                                          parentProcess:@"/test/process/parent"
                                                                        parentProcessId:@(0)];


    NRMACrashReport_SignalInfo* sigInfo = [[NRMACrashReport_SignalInfo alloc] initWithFaultAddress:@"testAddr"
                                                                                        signalCode:@"test_sig_code"
                                                                                        signalName:@"SIG_NAME"];
    NRMACrashReport_Exception* exception = [[NRMACrashReport_Exception alloc] initWithName:@"test_exception"
                                                                                     cause:@"test_cause"
                                                                                signalInfo:sigInfo];




    NRMACrashReport_Stack* stack = [[NRMACrashReport_Stack alloc] initWithInstructionPointer:@"0x12345678" symbol:nil];

    NRMACrashReport_Thread* thread = [[NRMACrashReport_Thread alloc] initWithCrashed:true
                                                                           registers:@{@"rax":@"0x51125343"}
                                                                    threadNumber:@(1)
                                                                            threadId:@"thread 1"
                                                                        priority:@(1)
                                                                               stack:[@[stack] mutableCopy]];

    NRMACrashReport_Library* library = [[NRMACrashReport_Library alloc] initWithBaseAddress:@"0x0555"
                                                                                  imageName:@"testImage"
                                                                                  imageSize:@(5345345)
                                                                                  imageUuid:@"imgUUID"
                                                                                   codeType:[[NRMACrashReport_CodeType alloc] initWithArch:@"arm64"
                                                                                                                              typeEncoding:@"encoding"]];
    
    

    NRMACrashReport* report = [[NRMACrashReport alloc] initWithUUID:@"asdf"
                                                    buildIdentifier:@"blah"
                                                          timestamp:@1
                                                           appToken:@"token"
                                                          accountId:@213
                                                            agentId:@1123
                                                         deviceInfo:deviceInfo
                                                            appInfo:appInfo
                                                          exception:exception
                                                            threads:[@[thread] mutableCopy]
                                                          libraries:[@[library] mutableCopy]
													activityHistory:@[@"uiTestActivity"]
                                                  sessionAttributes:@{@"session":@"attribute"}
                                                    AnalyticsEvents:@[@{@"eventType":@"testEvent"}]];

    XCTAssertNoThrow([report JSONObject]);
}

// TODO: Debug occasional crash on CFUUIDCreateString(NULL, report.uuidRef)
//                                 NRMACrashDataWriter
-(void) testCrashDataWriter {

     NSError *error;
     PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
     NSData *reportData = [reporter generateLiveReportAndReturnError: &error];
     XCTAssertNotNil(reportData, @"Failed to generate live report: %@", error);

     PLCrashReport *report = [[PLCrashReport alloc] initWithData: reportData error: &error];
     XCTAssertNotNil(report, @"Could not parse geneated live report: %@", error);

     XCTAssertEqualObjects([[report signalInfo] name], @"SIGTRAP", @"Incorrect signal name");
     XCTAssertEqualObjects([[report signalInfo] code], @"TRAP_TRACE", @"Incorrect signal code");

     XCTAssertNoThrow([NRMACrashDataWriter writeCrashReport:report withMetaData:Nil sessionAttributes:Nil], @"should not throw exception even with missing data.");

 }

// Writes the crash report via NRMACrashDataWriter and returns the JSON of
// whichever report file is newest in the crash report directory afterward.
- (NSDictionary *)writeCrashReportAndReadBackJSONWithMetaData:(NSDictionary *)metaDictionary
                                              sessionAttributes:(NSDictionary *)sessionAttributes {
    NSError *error;
    PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration:[PLCrashReporterConfig defaultConfiguration]];
    NSData *reportData = [reporter generateLiveReportAndReturnError:&error];
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:reportData error:&error];

    NSString *reportDirectory = [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), kNRMA_CR_ReportPath];
    NSSet *filesBefore = [NSSet setWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:reportDirectory error:nil] ?: @[]];

    BOOL success = [NRMACrashDataWriter writeCrashReport:report
                                             withMetaData:metaDictionary
                                        sessionAttributes:sessionAttributes];
    XCTAssertTrue(success);

    NSArray *filesAfter = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:reportDirectory error:nil];
    NSString *newFile = nil;
    for (NSString *fileName in filesAfter) {
        if (![filesBefore containsObject:fileName]) {
            newFile = fileName;
            break;
        }
    }
    XCTAssertNotNil(newFile, @"writeCrashReport: did not produce a new report file");

    NSString *fullPath = [reportDirectory stringByAppendingPathComponent:newFile];
    NSData *jsonData = [NSData dataWithContentsOfFile:fullPath];
    NSDictionary *json = [NRMAJSON JSONObjectWithData:jsonData options:0 error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
    return json;
}

- (void)testCrashDataWriterUsesPersistedManifestAttributesWhenFlagEnabledRegardlessOfPassedInAttributes {
    [NRMAFlags enableFeatures:NRFeatureFlag_EventPersistence];

    NSString *crashSessionId = @"crash-true-session-reattribution-test";
    [[NREventPersistenceController shared] writeSessionManifestWithSessionId:crashSessionId
                                                                   realAgentId:7
                                                                sessionStartMs:0
                                                              stableAttributes:@{@"appVersion": @"2.0"}];

    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: crashSessionId};
    // Primary source now when the flag is on, so these must be ignored.
    NSDictionary *passedInAttributes = @{@"sessionId": @"some-other-session", @"stale": @"shouldNotAppear"};

    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:passedInAttributes];

    NSDictionary *writtenAttributes = json[kNRMA_CR_sessionAttributes];
    XCTAssertEqualObjects(writtenAttributes[@"appVersion"], @"2.0",
                          @"when a manifest is found for the crash's true session, its attributes must be used");
    XCTAssertNil(writtenAttributes[@"stale"], @"the passed-in attributes must not survive -- NREventPersistenceController is authoritative");
    XCTAssertNotEqual(json[kNRMA_CR_analyticsEvents], [NSNull null],
                      @"events must not be dropped just because a manifest was found (even if none were persisted, it resolves to an empty array, not nil)");

    [NRMAFlags disableFeatures:NRFeatureFlag_EventPersistence];
}

// Regression guard: hasReplay is computed by NRMAExceptionHandlerManager from on-disk
// error-mode session replay frames at crash-processing time, not from the persisted
// manifest -- it must survive even though persisted attributes are otherwise authoritative.
- (void)testCrashDataWriterPreservesCallerHasReplayWhenFlagEnabled {
    [NRMAFlags enableFeatures:NRFeatureFlag_EventPersistence];

    NSString *crashSessionId = @"crash-has-replay-preservation-test";
    [[NREventPersistenceController shared] writeSessionManifestWithSessionId:crashSessionId
                                                                   realAgentId:7
                                                                sessionStartMs:0
                                                              stableAttributes:@{@"appVersion": @"2.0"}];

    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: crashSessionId};
    NSDictionary *passedInAttributes = @{kNRMA_RA_hasReplay: @YES};

    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:passedInAttributes];

    NSDictionary *writtenAttributes = json[kNRMA_CR_sessionAttributes];
    XCTAssertEqualObjects(writtenAttributes[@"appVersion"], @"2.0");
    XCTAssertEqualObjects(writtenAttributes[kNRMA_RA_hasReplay], @YES,
                          @"hasReplay is computed by the caller at crash-processing time and must not be dropped "
                          @"just because persisted manifest attributes are otherwise authoritative");

    [NRMAFlags disableFeatures:NRFeatureFlag_EventPersistence];
}

- (void)testCrashDataWriterDropsEverythingWhenFlagEnabledButNoManifestFound {
    [NRMAFlags enableFeatures:NRFeatureFlag_EventPersistence];

    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: @"crash-session-with-no-manifest"};
    NSDictionary *passedInAttributes = @{@"sessionId": @"crash-session-with-no-manifest", @"stale": @"shouldNotAppear"};

    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:passedInAttributes];

    XCTAssertEqualObjects(json[kNRMA_CR_sessionAttributes], [NSNull null],
                          @"with no manifest to resolve from, attributes (and events) must be dropped -- never attribute a crash to a guessed session");
    XCTAssertEqualObjects(json[kNRMA_CR_analyticsEvents], [NSNull null]);

    [NRMAFlags disableFeatures:NRFeatureFlag_EventPersistence];
}

- (void)testCrashDataWriterUsesPersistedEventsAsPrimarySourceAndClaimsThem {
    [NRMAFlags enableFeatures:NRFeatureFlag_EventPersistence];

    NSString *crashSessionId = @"crash-primary-event-source-test";
    [[NREventPersistenceController shared] writeSessionManifestWithSessionId:crashSessionId
                                                                   realAgentId:7
                                                                sessionStartMs:0
                                                              stableAttributes:@{@"appVersion": @"2.0"}];
    [[NREventPersistenceController shared] recordEventWithEventUUID:@"primary-event-source-uuid"
                                                            eventType:@"Mobile"
                                                          timestampMs:1000
                                                           attributes:@{@"name": @"MyEvent", @"orderId": @"XYZ"}
                                                            sessionId:crashSessionId
                                                          realAgentId:7];

    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: crashSessionId};
    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:@{@"sessionId": crashSessionId}];

    NSArray *writtenEvents = json[kNRMA_CR_analyticsEvents];
    XCTAssertEqual(writtenEvents.count, 1);
    XCTAssertEqualObjects(writtenEvents.firstObject[@"orderId"], @"XYZ");
    XCTAssertEqualObjects(writtenEvents.firstObject[@"appVersion"], @"2.0");

    XCTAssertEqual([[NREventPersistenceController shared] claimPersistedEventsForCrashSessionId:crashSessionId].count, 0,
                   @"writeCrashReport: must have already claimed (and deleted) this session's events, so a later claim finds nothing -- "
                   @"otherwise the same events could also be delivered via the next ordinary harvest's recovery sweep");

    [NRMAFlags disableFeatures:NRFeatureFlag_EventPersistence];
}

- (void)testCrashDataWriterStillDropsOnSessionMismatchWhenFlagDisabled {
    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: @"crash-true-session"};
    NSDictionary *mismatchedAttributes = @{@"sessionId": @"some-other-session", @"stale": @"shouldNotAppear"};

    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:mismatchedAttributes];

    XCTAssertEqualObjects(json[kNRMA_CR_sessionAttributes], [NSNull null],
                          @"with the flag disabled, a session mismatch must drop attributes exactly as before this feature existed");
    XCTAssertEqualObjects(json[kNRMA_CR_analyticsEvents], [NSNull null]);
}

- (void)testCrashDataWriterUsesPassedInAttributesWhenFlagDisabledAndSessionMatches {
    NSDictionary *metaDictionary = @{@kNRMAMetaKey_Session: @"matching-session"};
    NSDictionary *matchingAttributes = @{@"sessionId": @"matching-session", @"appVersion": @"1.0"};

    NSDictionary *json = [self writeCrashReportAndReadBackJSONWithMetaData:metaDictionary
                                                           sessionAttributes:matchingAttributes];

    NSDictionary *writtenAttributes = json[kNRMA_CR_sessionAttributes];
    XCTAssertEqualObjects(writtenAttributes[@"appVersion"], @"1.0",
                          @"with the flag disabled and a matching session, the passed-in attributes must be used unchanged");
    // The legacy event duplication store is no longer written to, so there is no
    // event source left for this path -- events must always be absent here.
    XCTAssertEqualObjects(json[kNRMA_CR_analyticsEvents], [NSNull null]);
}

 -(void) testExceptionHandlerManager {
     NRMAExceptionHandlerStartupManager* exceptionHandlerStartupManager = [[NRMAExceptionHandlerStartupManager alloc] init];
     NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                               applicationToken:@"token"
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];

     XCTAssertNoThrow([exceptionHandlerStartupManager startExceptionHandler:uploader]);

     NRMACrashDataUploader* badUploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                               applicationToken:nil
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];


     XCTAssertNoThrow([exceptionHandlerStartupManager startExceptionHandler:badUploader], @"missing application token should not throw exception");

 }

 -(void) testNRMACrashReportFileManager {
     PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
     NRMAExceptionHandlerStartupManager* exceptionHandlerStartupManager = [[NRMAExceptionHandlerStartupManager alloc] init];
     NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                               applicationToken:@"token"
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];

     [exceptionHandlerStartupManager startExceptionHandler:uploader];


     NRMACrashReportFileManager* fileManager = [[NRMACrashReportFileManager alloc] init];
     NRMACrashReportFileManager* fileManagerWithReporter = [[NRMACrashReportFileManager alloc] initWithCrashReporter:reporter];

     XCTAssertNoThrow([fileManagerWithReporter processReportsWithSessionAttributes:nil], @"missing attributes should not cause exception");
     XCTAssertNoThrow([fileManager processReportsWithSessionAttributes:nil], @"missing attributes should not cause exception");
 }

- (void) testGetOperatingDevice {
    NSString *operatingSystem = [NRMACrashDataWriter getOperatingDevice:PLCrashReportOperatingSystemMacOSX];
    XCTAssertEqualObjects(operatingSystem, @"OSX");
    
    operatingSystem = [NRMACrashDataWriter getOperatingDevice:PLCrashReportOperatingSystemiPhoneOS];
    XCTAssertEqualObjects(operatingSystem, @"iOS Device");
    
    operatingSystem = [NRMACrashDataWriter getOperatingDevice:PLCrashReportOperatingSystemiPhoneSimulator];
    XCTAssertEqualObjects(operatingSystem, @"iOS Simulator");

    operatingSystem = [NRMACrashDataWriter getOperatingDevice:PLCrashReportOperatingSystemAppleTVOS];
    XCTAssertEqualObjects(operatingSystem, @"tvOS Device");
    
    operatingSystem = [NRMACrashDataWriter getOperatingDevice:PLCrashReportOperatingSystemUnknown];
    XCTAssertEqualObjects(operatingSystem, @"Unknown");
}

- (void) testGetArchitectureFromProcessorInfo {
    PLCrashReportProcessorInfo* info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM subtype:CPU_SUBTYPE_ARM_V7S];
    NSString *architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"armv7s");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM subtype:CPU_SUBTYPE_ARM_V6];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"armv6");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM subtype:CPU_SUBTYPE_ARM_V7F];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"armv7");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM subtype:0];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"arm-unknown");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM64 subtype:CPU_SUBTYPE_ARM64_ALL];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"arm64");

    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM64 subtype:CPU_SUBTYPE_ARM64_V8];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"arm64");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM64 subtype:CPU_SUBTYPE_ARM64E];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"arm64e");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ARM64 subtype:10];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"arm64-unknown");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_X86 subtype:0];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"i386");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_X86_64 subtype:0];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"x86_64");
    
    info = [[PLCrashReportProcessorInfo alloc] initWithTypeEncoding:PLCrashReportProcessorTypeEncodingMach type:CPU_TYPE_ANY subtype:0];
    architecture = [NRMACrashDataWriter getArchitectureFromProcessorInfo:info];
    XCTAssertEqualObjects(architecture, @"Unknown");
}

- (void) testGetProcessorArchType {
    NSString *processorArchType = [NRMACrashDataWriter getProcessorArchType:PLCrashReportProcessorTypeEncodingMach];
    XCTAssertEqualObjects(processorArchType, @"Mach");
    
    processorArchType = [NRMACrashDataWriter getProcessorArchType:PLCrashReportProcessorTypeEncodingUnknown];
    XCTAssertEqualObjects(processorArchType, @"Unknown");
}

- (void) testStartCrashMetaDataMonitors {
    XCTAssertNoThrow([NRMAExceptionDataCollectionWrapper startCrashMetaDataMonitors]);
    
#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:nil];
#endif
    [NRMAExceptionDataCollectionWrapper endMonitoringOrientation];
}

@end
