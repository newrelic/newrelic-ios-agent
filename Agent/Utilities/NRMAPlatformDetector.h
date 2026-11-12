//
//  NRMAPlatformDetector.h
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRConstants.h"

NS_ASSUME_NONNULL_BEGIN

// How a platform was found, strongest signal first.
typedef NS_ENUM(NSInteger, NRMAPlatformDetectionSource) {
    // A New Relic hybrid plugin class declared the platform (and maybe its version) through NRMAHybridPlatformDeclaring.
    NRMAPlatformDetectionSource_PluginDeclaration,
    // A New Relic hybrid plugin class is in the app but does not declare anything (a plugin release that predates the declaration).
    NRMAPlatformDetectionSource_PluginClass,
    // A class of the framework itself is registered.
    NRMAPlatformDetectionSource_FrameworkClass,
    // Both of the framework's marker files are in the app bundle.
    NRMAPlatformDetectionSource_FrameworkBundleFiles
};

@interface NRMAPlatformDetection : NSObject
@property(nonatomic, readonly) NRMAApplicationPlatform platform;
// Only a plugin declaration carries a version.
@property(nonatomic, readonly, nullable) NSString* platformVersion;
@property(nonatomic, readonly) NRMAPlatformDetectionSource source;

- (instancetype) initWithPlatform:(NRMAApplicationPlatform)platform
                  platformVersion:(nullable NSString*)platformVersion
                           source:(NRMAPlatformDetectionSource)source;
- (instancetype) init NS_UNAVAILABLE;
@end

/*
 * The contract a New Relic hybrid plugin implements on its main Objective-C class (for example NRMModularAgent)
 * so the agent knows the platform however it is started, even before any hybrid code runs. Both methods must
 * return constants: the agent calls them while it starts.
 *
 * +newRelicApplicationPlatform returns a platform name as spelled by stringFromNRMAApplicationPlatform: (for example
 * @"ReactNative"), compared without case. +newRelicApplicationPlatformVersion returns the plugin's own version.
 */
@protocol NRMAHybridPlatformDeclaring <NSObject>
@optional
+ (NSString*) newRelicApplicationPlatform;
+ (NSString*) newRelicApplicationPlatformVersion;
@end

@interface NRMAPlatformDetector : NSObject

// Looks in the running app. Returns nil when nothing matches, which means Native.
+ (nullable NRMAPlatformDetection*) detectPlatform;

// The same rules with injectable signal sources, for tests. runtimeClassName returns the name of the class that
// stands for className in the runtime (className itself in the app), or nil when there is none.
+ (nullable NRMAPlatformDetection*) detectPlatformWithRuntimeClassName:(NSString* _Nullable (^)(NSString* className))runtimeClassName
                                                           fileExists:(BOOL (^)(NSString* bundleRelativePath))fileExists;

@end

NS_ASSUME_NONNULL_END
