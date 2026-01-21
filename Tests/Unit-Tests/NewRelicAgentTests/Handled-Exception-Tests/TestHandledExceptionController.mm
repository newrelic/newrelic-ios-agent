//
//  TestHandledExceptionController.m
//  NewRelic
//
//  Created by Bryce Buchanan on 6/28/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMABool.h"
#import "NRMAHandledExceptions.h"
#import "NRMAExceptionReportAdaptor.h"
#import "NRMAAgentConfiguration.h"

#import "NewRelicInternalUtils.h"
#import "NRMAAttributeValidator.h"

#import <Hex/HexContext.hpp>
#import "NRAgentTestBase.h"
#import "NRLogger.h"
#import "NRMAAppToken.h"
#import <OCMock/OCMock.h>
#import "NRMAFlags.h"

@interface TestHandledExceptionController : NRMAAgentTestBase {
    unsigned long long epoch_time_ms;
    const char* sessionDataPath;
}

@end


@interface NRMAExceptionReportAdaptor()
- (void) addKey:(NSString*)key
    stringValue:(NSString*)string;

- (void) addKey:(NSString*)key
      boolValue:(NRMABool*)boolean;

- (void) addKey:(NSString*)key
    numberValue:(NSNumber*)num;
@end

@interface NRMAHandledExceptions ()
- (fbs::Platform) fbsPlatformFromString:(NSString*)platform;
@end

@implementation TestHandledExceptionController

- (void) setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void) testBadParams {
    [NRLogger setLogLevels:NRLogLevelALL];
    XCTAssertNoThrow([[NRMAHandledExceptions alloc] initWithAnalyticsController:nil
                                                               sessionStartTime:0
                                                             agentConfiguration:nil
                                                                       platform:nil
                                                                      sessionId:nil
                                                             attributeValidator:nil]);

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAHandledExceptions* exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:nil
                                                                                  sessionStartTime:0
                                                                                agentConfiguration:nil
                                                                                          platform:nil
                                                                                         sessionId:nil
                                                                                attributeValidator:nil];


    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:nil
                                                                   platform:nil
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"12345"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:agentConfig
                                                                   platform:nil
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:agentConfig
                                                                   platform:@"iOS"
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);
}

- (void) testBadParamsNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];

    [NRLogger setLogLevels:NRLogLevelALL];
    XCTAssertNoThrow([[NRMAHandledExceptions alloc] initWithAnalyticsController:nil
                                                               sessionStartTime:0
                                                             agentConfiguration:nil
                                                                       platform:nil
                                                                      sessionId:nil
                                                             attributeValidator:nil]);

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAHandledExceptions* exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:nil
                                                                                  sessionStartTime:0
                                                                                agentConfiguration:nil
                                                                                          platform:nil
                                                                                         sessionId:nil
                                                                                attributeValidator:nil];


    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:nil
                                                                   platform:nil
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"12345"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:agentConfig
                                                                   platform:nil
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    exceptions = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                           sessionStartTime:0
                                                         agentConfiguration:agentConfig
                                                                   platform:@"iOS"
                                                                  sessionId:nil
                                                         attributeValidator:nil];

    XCTAssertTrue(exceptions == nil);

    XCTAssertNoThrow([exceptions recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]]);

    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
}

- (void) testHandleException {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];

    XCTAssertNoThrow([hexController recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception"
                                                                                   reason:@"the Tea is too hot"
                                                                                 userInfo:@{}]]);

    XCTAssertNoThrow([hexController recordHandledException:nil]);

    NSDictionary* dict = @{@"string":@"string",
            @"num":@1};
    XCTAssertNoThrow([hexController recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception"
                                                                                   reason:@"the tea is too hot"
                                                                                 userInfo:nil]
                                                attributes:dict]);

    XCTAssertNoThrow([hexController recordHandledException:nil
                                                attributes:dict]);
}

// Old Event System
- (void) testHandleExceptionWithStackTrace {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];

    id dict = @{@"name": @"Exception name not found",
                @"reason": @"Reason not found",
                @"cause": @"Reason not found",
                @"fatal": @false,
                @"stackTraceElements": @[@{@"class": @"className", @"method": @"methodName", @"file": @"fileName", @"line": @"1"}],
                @"appBuild": @"8",
                @"appVersion": @"8"};

    XCTAssertNoThrow([hexController recordHandledExceptionWithStackTrace:dict]);
}

// New Event System
- (void) testHandleExceptionWithStackTraceNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];

    id dict = @{@"name": @"Exception name not found",
                @"reason": @"Reason not found",
                @"cause": @"Reason not found",
                @"fatal": @false,
                @"stackTraceElements": @[@{@"class": @"className", @"method": @"methodName", @"file": @"fileName", @"line": @"1"}],
                @"appBuild": @"8",
                @"appVersion": @"8"};

    XCTAssertNoThrow([hexController recordHandledExceptionWithStackTrace:dict]);


    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];

}

- (void) testPlatform {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];
    XCTAssertTrue([hexController fbsPlatformFromString:@"iOS"] == com::newrelic::mobile::fbs::Platform_iOS, @"Method returned %d, but should be %d", [hexController fbsPlatformFromString:@"iOS"],com::newrelic::mobile::fbs::Platform_iOS );
    XCTAssertTrue([hexController fbsPlatformFromString:@"tvOS"] == com::newrelic::mobile::fbs::Platform_tvOS,@"Method returned %d, but should be %d", [hexController fbsPlatformFromString:@"tvOS"],com::newrelic::mobile::fbs::Platform_tvOS);

}

- (void) testDontRecordUnThrownExceptions {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";
    agentConfig.platform = NRMAPlatform_Native;

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];
    
    id mockLogger = [OCMockObject mockForClass:[NRLogger class]];
    
    
    [[[[mockLogger expect] ignoringNonObjectArgs] classMethod]  log:0
                                                            inFile:OCMOCK_ANY
                                                            atLine:0
                                                          inMethod:OCMOCK_ANY
                                                        withMessage:[OCMArg checkWithBlock:^BOOL(NSString* obj) {
        return [obj containsString:@"Invalid exception."];
    }] withAgentLogsOn: YES];

    
    XCTAssertNoThrow([hexController recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception"
                                                                                   reason:@"the Tea is too hot"
                                                                                 userInfo:@{}]]);
    
    XCTAssertNoThrow([mockLogger verify]);
    
    [mockLogger stopMocking];
    
}

- (void) testRecordError {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];
    
    
    NSError* error = [NSError errorWithDomain:@"" code:NSURLErrorUnknown userInfo:@{}];
    
    XCTAssertNoThrow([hexController recordError:error attributes:@{@"":[NSNull new]}]);
    
    // Error.Domain being nil should be throwing an exception (declared as NONNULL)
    XCTAssertThrowsSpecificNamed([NSError errorWithDomain:nil code:NSURLErrorUnknown userInfo:@{}], NSException, NSInvalidArgumentException);
    
    // Error.localizedDescription being nil should be throwing an exception (declared as NONNULL)
    error = [NSError errorWithDomain:@"Unknown" code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey:[NSNull new]}];
    XCTAssertThrowsSpecificNamed([hexController recordError:error attributes:nil], NSException, NSInvalidArgumentException);
    
    // User should not have access to call recordError:nil, will crash if nil is passed (warning will be given)
    //[hexController recordError:nil attributes:nil]
    
}

- (void) testRecordErrorNewEventSystem {
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];

    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 newSession: true];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"blah"]
                                                                          collectorAddress:nil
                                                                              crashAddress:nil];
    agentConfig.sessionIdentifier = @"1234-567-890";

    NRMAHandledExceptions* hexController = [[NRMAHandledExceptions alloc] initWithAnalyticsController:analytics
                                                                                     sessionStartTime:[NSDate new]
                                                                                   agentConfiguration:agentConfig
                                                                                             platform:[NewRelicInternalUtils osName]
                                                                                            sessionId:@"sessionId"
                                                                                   attributeValidator:[[NRMAAttributeValidator alloc] init]];


    NSError* error = [NSError errorWithDomain:@"" code:NSURLErrorUnknown userInfo:@{}];

    XCTAssertNoThrow([hexController recordError:error attributes:@{@"":[NSNull new]}]);

    // Error.Domain being nil should be throwing an exception (declared as NONNULL)
    XCTAssertThrowsSpecificNamed([NSError errorWithDomain:nil code:NSURLErrorUnknown userInfo:@{}], NSException, NSInvalidArgumentException);

    // Error.localizedDescription being nil should be throwing an exception (declared as NONNULL)
    error = [NSError errorWithDomain:@"Unknown" code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey:[NSNull new]}];
    XCTAssertThrowsSpecificNamed([hexController recordError:error attributes:nil], NSException, NSInvalidArgumentException);

    // User should not have access to call recordError:nil, will crash if nil is passed (warning will be given)
    //[hexController recordError:nil attributes:nil]
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];

}

@end
