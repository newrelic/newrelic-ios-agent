//
//  NRMAPlatformDetector.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAPlatformDetector.h"
#import "NewRelicInternalUtils.h"
#import <objc/runtime.h>

@implementation NRMAPlatformDetection

- (instancetype) initWithPlatform:(NRMAApplicationPlatform)platform
                  platformVersion:(NSString*)platformVersion
                           source:(NRMAPlatformDetectionSource)source {
    self = [super init];
    if (self) {
        _platform = platform;
        _platformVersion = [platformVersion copy];
        _source = source;
    }
    return self;
}

@end

typedef struct {
    NRMAApplicationPlatform platform;
    const char* pluginClass;          // the New Relic hybrid plugin's Objective-C class, NULL when there is none
    const char* frameworkClasses[3];  // any one is enough
    const char* bundleFiles[2];       // both are needed
} NRMAPlatformRule;

// First match wins. Capacitor ships CapacitorCordova, which defines the CDV* classes, so it comes before Cordova.
// Unity is last because it is usually embedded in another framework's app. MAUI has no rule: its plugin always
// calls +setPlatform: before it starts the agent.
// Only specific Objective-C names are looked up. Never enumerate the registered classes (NR-588325).
static const NRMAPlatformRule kNRMAPlatformRules[] = {
    { NRMAPlatform_Capacitor,   "NewRelicCapacitorPluginPlugin", { "CAPPluginCall", NULL, NULL },                       { "capacitor.config.json", "public" } },
    { NRMAPlatform_Cordova,     "NewRelicCordovaPlugin",         { "CDVViewController", "CDVPlugin", NULL },            { "config.xml", "www" } },
    { NRMAPlatform_ReactNative, "NRMModularAgent",               { "RCTBridge", "RCTHost", "RCTRootView" },             { "main.jsbundle", "Frameworks/hermes.framework" } },
    { NRMAPlatform_Flutter,     "NewrelicMobilePlugin",          { "FlutterEngine", "FlutterViewController", NULL },    { "Frameworks/Flutter.framework", "Frameworks/App.framework/flutter_assets" } },
    { NRMAPlatform_Unity,       NULL,                            { "UnityAppController", "UnityFramework", NULL },      { "Frameworks/UnityFramework.framework", "Data" } },
};

static const size_t kNRMAPlatformRuleCount = sizeof(kNRMAPlatformRules) / sizeof(kNRMAPlatformRules[0]);

// A looked-up class is only ever held __unsafe_unretained and never returned. Under ARC a strong or returned Class
// is sent -retain, and a message to a class that is not initialized yet runs its +initialize, so a plain lookup would
// run third-party code at agent start. objc_lookUpClass sends no message.
static NSString* NRMARuntimeClassName(const char* className, NSString* (^runtimeClassName)(NSString*)) {
    return className ? runtimeClassName(@(className)) : nil;
}

static BOOL NRMAClassExists(const char* className, NSString* (^runtimeClassName)(NSString*)) {
    NSString* name = NRMARuntimeClassName(className, runtimeClassName);
    return name && objc_lookUpClass(name.UTF8String) != Nil;
}

// Reads the metaclass's own method list, which sends the class no message: a plugin class that declares nothing
// stays uninitialized.
static BOOL NRMAClassDefinesClassMethod(__unsafe_unretained Class cls, SEL selector) {
    unsigned int count = 0;
    Method* methods = class_copyMethodList(object_getClass(cls), &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count && !found; i++) {
        found = method_getName(methods[i]) == selector;
    }
    free(methods);
    return found;
}

// Native is never a match: a declaration of Native says nothing the default does not.
static BOOL NRMAPlatformFromName(NSString* name, NRMAApplicationPlatform* platform) {
    NSString* trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NRMAApplicationPlatform candidate = NRMAPlatform_Cordova; candidate <= NRMAPlatform_Unreal; candidate++) {
        if ([trimmed caseInsensitiveCompare:[NewRelicInternalUtils stringFromNRMAApplicationPlatform:candidate]] == NSOrderedSame) {
            *platform = candidate;
            return YES;
        }
    }
    return NO;
}

// Only a class that declares the platform is sent a message, and that runs its +initialize as any first message does.
static NRMAPlatformDetection* NRMADeclarationOfPluginClass(const char* className, NSString* (^runtimeClassName)(NSString*)) {
    NSString* name = NRMARuntimeClassName(className, runtimeClassName);
    __unsafe_unretained Class pluginClass = name ? objc_lookUpClass(name.UTF8String) : Nil;
    if (!pluginClass || !NRMAClassDefinesClassMethod(pluginClass, @selector(newRelicApplicationPlatform))) {
        return nil;
    }

    id declaredPlatform = [(Class<NRMAHybridPlatformDeclaring>)pluginClass newRelicApplicationPlatform];
    NRMAApplicationPlatform platform;
    if (![declaredPlatform isKindOfClass:[NSString class]] || !NRMAPlatformFromName(declaredPlatform, &platform)) {
        return nil;
    }

    NSString* platformVersion = nil;
    if (NRMAClassDefinesClassMethod(pluginClass, @selector(newRelicApplicationPlatformVersion))) {
        id declaredVersion = [(Class<NRMAHybridPlatformDeclaring>)pluginClass newRelicApplicationPlatformVersion];
        if ([declaredVersion isKindOfClass:[NSString class]]) {
            NSString* trimmed = [declaredVersion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            platformVersion = trimmed.length ? trimmed : nil;
        }
    }

    return [[NRMAPlatformDetection alloc] initWithPlatform:platform
                                           platformVersion:platformVersion
                                                    source:NRMAPlatformDetectionSource_PluginDeclaration];
}

@implementation NRMAPlatformDetector

+ (NRMAPlatformDetection*) detectPlatform {
    NSString* bundlePath = [NSBundle mainBundle].bundlePath;
    NSFileManager* fileManager = [NSFileManager defaultManager];

    return [self detectPlatformWithRuntimeClassName:^NSString*(NSString* className) {
        return className;
    } fileExists:^BOOL(NSString* bundleRelativePath) {
        return [fileManager fileExistsAtPath:[bundlePath stringByAppendingPathComponent:bundleRelativePath]];
    }];
}

+ (NRMAPlatformDetection*) detectPlatformWithRuntimeClassName:(NSString* (^)(NSString*))runtimeClassName
                                                   fileExists:(BOOL (^)(NSString*))fileExists {
    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        NRMAPlatformDetection* declared = NRMADeclarationOfPluginClass(kNRMAPlatformRules[i].pluginClass, runtimeClassName);
        if (declared) {
            return declared;
        }
    }

    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        if (NRMAClassExists(kNRMAPlatformRules[i].pluginClass, runtimeClassName)) {
            return [[NRMAPlatformDetection alloc] initWithPlatform:kNRMAPlatformRules[i].platform
                                                   platformVersion:nil
                                                            source:NRMAPlatformDetectionSource_PluginClass];
        }
    }

    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        for (size_t c = 0; c < 3; c++) {
            if (NRMAClassExists(kNRMAPlatformRules[i].frameworkClasses[c], runtimeClassName)) {
                return [[NRMAPlatformDetection alloc] initWithPlatform:kNRMAPlatformRules[i].platform
                                                       platformVersion:nil
                                                                source:NRMAPlatformDetectionSource_FrameworkClass];
            }
        }
    }

    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        if (fileExists(@(kNRMAPlatformRules[i].bundleFiles[0])) && fileExists(@(kNRMAPlatformRules[i].bundleFiles[1]))) {
            return [[NRMAPlatformDetection alloc] initWithPlatform:kNRMAPlatformRules[i].platform
                                                   platformVersion:nil
                                                            source:NRMAPlatformDetectionSource_FrameworkBundleFiles];
        }
    }

    return nil;
}

@end
