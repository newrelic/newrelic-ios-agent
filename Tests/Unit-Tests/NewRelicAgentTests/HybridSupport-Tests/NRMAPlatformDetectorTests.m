//
//  NRMAPlatformDetectorTests.m
//  Agent_Tests
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAPlatformDetector.h"
#import "NRMAAgentConfiguration.h"

// Stand-ins for New Relic hybrid plugin classes. The tests only ever refer to them by name, so
// NRMAFakeSilentPlugin can tell whether the detector sent it a message.

@interface NRMAFakeDeclaringPlugin : NSObject
@end
@implementation NRMAFakeDeclaringPlugin
+ (NSString*) newRelicApplicationPlatform { return @"reactnative"; }
+ (NSString*) newRelicApplicationPlatformVersion { return @" 1.9.3 "; }
@end

@interface NRMAFakeNativeDeclaringPlugin : NSObject
@end
@implementation NRMAFakeNativeDeclaringPlugin
+ (NSString*) newRelicApplicationPlatform { return @"Native"; }
+ (NSString*) newRelicApplicationPlatformVersion { return @"1.0.0"; }
@end

@interface NRMAFakeUnknownDeclaringPlugin : NSObject
@end
@implementation NRMAFakeUnknownDeclaringPlugin
+ (NSString*) newRelicApplicationPlatform { return @"NotAFramework"; }
@end

@interface NRMAFakeVersionlessDeclaringPlugin : NSObject
@end
@implementation NRMAFakeVersionlessDeclaringPlugin
+ (NSString*) newRelicApplicationPlatform { return @"Flutter"; }
@end

static BOOL NRMAFakeSilentPluginInitialized = NO;

@interface NRMAFakeSilentPlugin : NSObject
@end
@implementation NRMAFakeSilentPlugin
+ (void) initialize { NRMAFakeSilentPluginInitialized = YES; }
@end

static BOOL NRMAFakeFrameworkClassInitialized = NO;

@interface NRMAFakeFrameworkClass : NSObject
@end
@implementation NRMAFakeFrameworkClass
+ (void) initialize { NRMAFakeFrameworkClassInitialized = YES; }
@end

@interface NRMAPlatformDetectorTests : XCTestCase
@end

@implementation NRMAPlatformDetectorTests

#pragma mark - Helpers

// classes maps a name the detector looks up to the name of a real class that stands in for it.
- (NRMAPlatformDetection*) detectWithClasses:(NSDictionary<NSString*, NSString*>*)classes files:(NSArray<NSString*>*)files {
    return [NRMAPlatformDetector detectPlatformWithRuntimeClassName:^NSString*(NSString* className) {
        return classes[className];
    } fileExists:^BOOL(NSString* bundleRelativePath) {
        return [files containsObject:bundleRelativePath];
    }];
}

- (void) assertDetection:(NRMAPlatformDetection*)detection
                platform:(NRMAApplicationPlatform)platform
                  source:(NRMAPlatformDetectionSource)source
                 version:(NSString*)version {
    XCTAssertNotNil(detection);
    XCTAssertEqual(detection.platform, platform);
    XCTAssertEqual(detection.source, source);
    XCTAssertEqualObjects(detection.platformVersion, version);
}

#pragma mark - Detector

- (void) testNothingFoundIsNil {
    XCTAssertNil([self detectWithClasses:@{} files:@[]]);
}

- (void) testNativeTestHostIsNil {
    XCTAssertNil([NRMAPlatformDetector detectPlatform]);
}

- (void) testEachFrameworkByOneClass {
    NSDictionary<NSString*, NSNumber*>* expected = @{
        @"CAPPluginCall"         : @(NRMAPlatform_Capacitor),
        @"CDVViewController"     : @(NRMAPlatform_Cordova),
        @"CDVPlugin"             : @(NRMAPlatform_Cordova),
        @"RCTBridge"             : @(NRMAPlatform_ReactNative),
        @"RCTHost"               : @(NRMAPlatform_ReactNative),
        @"RCTRootView"           : @(NRMAPlatform_ReactNative),
        @"FlutterEngine"         : @(NRMAPlatform_Flutter),
        @"FlutterViewController" : @(NRMAPlatform_Flutter),
        @"UnityAppController"    : @(NRMAPlatform_Unity),
        @"UnityFramework"        : @(NRMAPlatform_Unity),
    };
    [expected enumerateKeysAndObjectsUsingBlock:^(NSString* className, NSNumber* platform, BOOL* stop) {
        NRMAPlatformDetection* detection = [self detectWithClasses:@{ className : @"NSObject" } files:@[]];
        XCTAssertEqual(detection.platform, platform.unsignedIntegerValue, @"%@", className);
        XCTAssertEqual(detection.source, NRMAPlatformDetectionSource_FrameworkClass, @"%@", className);
    }];
}

- (void) testEachFrameworkByBothBundleFiles {
    NSDictionary<NSNumber*, NSArray<NSString*>*>* expected = @{
        @(NRMAPlatform_Capacitor)   : @[ @"capacitor.config.json", @"public" ],
        @(NRMAPlatform_Cordova)     : @[ @"config.xml", @"www" ],
        @(NRMAPlatform_ReactNative) : @[ @"main.jsbundle", @"Frameworks/hermes.framework" ],
        @(NRMAPlatform_Flutter)     : @[ @"Frameworks/Flutter.framework", @"Frameworks/App.framework/flutter_assets" ],
        @(NRMAPlatform_Unity)       : @[ @"Frameworks/UnityFramework.framework", @"Data" ],
    };
    [expected enumerateKeysAndObjectsUsingBlock:^(NSNumber* platform, NSArray<NSString*>* files, BOOL* stop) {
        NRMAPlatformDetection* detection = [self detectWithClasses:@{} files:files];
        XCTAssertEqual(detection.platform, platform.unsignedIntegerValue, @"%@", files);
        XCTAssertEqual(detection.source, NRMAPlatformDetectionSource_FrameworkBundleFiles, @"%@", files);

        XCTAssertNil([self detectWithClasses:@{} files:@[ files[0] ]], @"%@ alone", files[0]);
        XCTAssertNil([self detectWithClasses:@{} files:@[ files[1] ]], @"%@ alone", files[1]);
    }];
}

- (void) testCapacitorWinsOverCordova {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"CAPPluginCall" : @"NSObject", @"CDVPlugin" : @"NSObject" } files:@[]];
    XCTAssertEqual(detection.platform, NRMAPlatform_Capacitor);
}

- (void) testHostFrameworkWinsOverEmbeddedUnity {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"UnityFramework" : @"NSObject", @"RCTBridge" : @"NSObject" } files:@[]];
    XCTAssertEqual(detection.platform, NRMAPlatform_ReactNative);
}

- (void) testFrameworkClassWinsOverBundleFiles {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"FlutterEngine" : @"NSObject" }
                                                         files:@[ @"main.jsbundle", @"Frameworks/hermes.framework" ]];
    [self assertDetection:detection platform:NRMAPlatform_Flutter source:NRMAPlatformDetectionSource_FrameworkClass version:nil];
}

- (void) testPluginClassWinsOverFrameworkClasses {
    // An app with Capacitor in it whose New Relic plugin is the Flutter one.
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NewrelicMobilePlugin" : @"NRMAFakeSilentPlugin",
                                                                  @"CAPPluginCall" : @"NSObject" } files:@[]];
    [self assertDetection:detection platform:NRMAPlatform_Flutter source:NRMAPlatformDetectionSource_PluginClass version:nil];
}

- (void) testEachPluginClass {
    NSDictionary<NSString*, NSNumber*>* expected = @{
        @"NewRelicCapacitorPluginPlugin" : @(NRMAPlatform_Capacitor),
        @"NewRelicCordovaPlugin"         : @(NRMAPlatform_Cordova),
        @"NRMModularAgent"               : @(NRMAPlatform_ReactNative),
        @"NewrelicMobilePlugin"          : @(NRMAPlatform_Flutter),
    };
    [expected enumerateKeysAndObjectsUsingBlock:^(NSString* className, NSNumber* platform, BOOL* stop) {
        NRMAPlatformDetection* detection = [self detectWithClasses:@{ className : @"NSObject" } files:@[]];
        XCTAssertEqual(detection.platform, platform.unsignedIntegerValue, @"%@", className);
        XCTAssertEqual(detection.source, NRMAPlatformDetectionSource_PluginClass, @"%@", className);
    }];
}

- (void) testPluginDeclarationWinsAndCarriesVersion {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NRMModularAgent" : @"NRMAFakeDeclaringPlugin",
                                                                  @"CAPPluginCall" : @"NSObject" }
                                                         files:@[ @"config.xml", @"www" ]];
    [self assertDetection:detection platform:NRMAPlatform_ReactNative source:NRMAPlatformDetectionSource_PluginDeclaration version:@"1.9.3"];
}

- (void) testPluginDeclarationWinsOverAHigherRankedSilentPlugin {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NewRelicCapacitorPluginPlugin" : @"NRMAFakeSilentPlugin",
                                                                  @"NRMModularAgent" : @"NRMAFakeDeclaringPlugin" } files:@[]];
    [self assertDetection:detection platform:NRMAPlatform_ReactNative source:NRMAPlatformDetectionSource_PluginDeclaration version:@"1.9.3"];
}

- (void) testDeclarationWithoutVersion {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NewrelicMobilePlugin" : @"NRMAFakeVersionlessDeclaringPlugin" } files:@[]];
    [self assertDetection:detection platform:NRMAPlatform_Flutter source:NRMAPlatformDetectionSource_PluginDeclaration version:nil];
}

- (void) testUnusableDeclarationFallsBackToThePluginClass {
    for (NSString* standIn in @[ @"NRMAFakeNativeDeclaringPlugin", @"NRMAFakeUnknownDeclaringPlugin" ]) {
        NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NewrelicMobilePlugin" : standIn } files:@[]];
        [self assertDetection:detection platform:NRMAPlatform_Flutter source:NRMAPlatformDetectionSource_PluginClass version:nil];
    }
}

- (void) testSilentPluginIsNeverMessaged {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"NRMModularAgent" : @"NRMAFakeSilentPlugin" } files:@[]];
    XCTAssertEqual(detection.platform, NRMAPlatform_ReactNative);
    XCTAssertFalse(NRMAFakeSilentPluginInitialized);
}

- (void) testFrameworkClassIsNeverMessaged {
    NRMAPlatformDetection* detection = [self detectWithClasses:@{ @"FlutterEngine" : @"NRMAFakeFrameworkClass" } files:@[]];
    XCTAssertEqual(detection.platform, NRMAPlatform_Flutter);
    XCTAssertFalse(NRMAFakeFrameworkClassInitialized);
}

#pragma mark - Resolver

- (void) setUp {
    [super setUp];
    [NRMAAgentConfiguration resetPlatformForTesting];
}

- (void) tearDown {
    [NRMAAgentConfiguration resetPlatformForTesting];
    [super tearDown];
}

- (NRMADeviceInformation*) deviceInformation {
    return [NRMAAgentConfiguration connectionInformation].deviceInformation;
}

- (NRMAPlatformDetection*) reactNativeDetection {
    return [[NRMAPlatformDetection alloc] initWithPlatform:NRMAPlatform_ReactNative
                                           platformVersion:@"1.9.3"
                                                    source:NRMAPlatformDetectionSource_PluginDeclaration];
}

- (void) testDetectedPlatformAndVersionAreUsed {
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* { return [self reactNativeDetection]; }];

    XCTAssertEqual([self deviceInformation].platform, NRMAPlatform_ReactNative);
    XCTAssertEqualObjects([self deviceInformation].platformVersion, @"1.9.3");
    XCTAssertFalse([NRMAAgentConfiguration isPlatformExplicit]);
}

- (void) testNothingDetectedIsNativeWithTheDefaultVersion {
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* { return nil; }];

    XCTAssertEqual([self deviceInformation].platform, NRMAPlatform_Native);
    XCTAssertNil([self deviceInformation].platformVersion);
}

- (void) testExplicitPlatformWinsAndTheDetectorDoesNotRun {
    for (NSNumber* explicitPlatform in @[ @(NRMAPlatform_Flutter), @(NRMAPlatform_Native) ]) {
        [NRMAAgentConfiguration resetPlatformForTesting];
        [NRMAAgentConfiguration setPlatform:explicitPlatform.unsignedIntegerValue];

        __block BOOL detectorRan = NO;
        [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* {
            detectorRan = YES;
            return [self reactNativeDetection];
        }];

        XCTAssertFalse(detectorRan);
        XCTAssertEqual([self deviceInformation].platform, explicitPlatform.unsignedIntegerValue);
        XCTAssertNil([self deviceInformation].platformVersion);
    }
}

- (void) testExplicitVersionIsKept {
    [NRMAAgentConfiguration setPlatformVersion:@"5.0.0"];
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* { return [self reactNativeDetection]; }];

    XCTAssertEqual([self deviceInformation].platform, NRMAPlatform_ReactNative);
    XCTAssertEqualObjects([self deviceInformation].platformVersion, @"5.0.0");
}

- (void) testDetectorFailureFallsBackToNative {
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* { return [self reactNativeDetection]; }];
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* {
        @throw [NSException exceptionWithName:@"TestException" reason:@"detector failed" userInfo:nil];
    }];

    XCTAssertEqual([self deviceInformation].platform, NRMAPlatform_Native);
    XCTAssertNil([self deviceInformation].platformVersion);
}

- (void) testLaterExplicitCallWinsOverDetection {
    [NRMAAgentConfiguration resolvePlatformWithDetector:^NRMAPlatformDetection* { return [self reactNativeDetection]; }];
    [NRMAAgentConfiguration setPlatform:NRMAPlatform_Flutter];

    XCTAssertEqual([self deviceInformation].platform, NRMAPlatform_Flutter);
    XCTAssertTrue([NRMAAgentConfiguration isPlatformExplicit]);
}

- (void) testExplicitFlag {
    XCTAssertFalse([NRMAAgentConfiguration isPlatformExplicit]);
    [NRMAAgentConfiguration setPlatformVersion:@"1.0.0"];
    XCTAssertFalse([NRMAAgentConfiguration isPlatformExplicit]);
    [NRMAAgentConfiguration setPlatform:NRMAPlatform_Native];
    XCTAssertTrue([NRMAAgentConfiguration isPlatformExplicit]);
}

@end
