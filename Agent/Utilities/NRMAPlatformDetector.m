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

// Reads the metaclass's own method list instead of sending -respondsToSelector:, so a plugin class that does not
// declare anything is never sent a message (and its +initialize never runs because of the agent).
static BOOL NRMAClassDefinesClassMethod(Class cls, SEL selector) {
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

@implementation NRMAPlatformDetector

+ (NRMAPlatformDetection*) detectPlatform {
    NSString* bundlePath = [NSBundle mainBundle].bundlePath;
    NSFileManager* fileManager = [NSFileManager defaultManager];

    return [self detectPlatformWithClassLookup:^Class(NSString* className) {
        return NSClassFromString(className);
    } fileExists:^BOOL(NSString* bundleRelativePath) {
        return [fileManager fileExistsAtPath:[bundlePath stringByAppendingPathComponent:bundleRelativePath]];
    }];
}

+ (NRMAPlatformDetection*) detectPlatformWithClassLookup:(Class (^)(NSString*))classLookup
                                              fileExists:(BOOL (^)(NSString*))fileExists {
    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        Class pluginClass = [self lookUp:kNRMAPlatformRules[i].pluginClass with:classLookup];
        NRMAPlatformDetection* declared = [self declarationOfPluginClass:pluginClass];
        if (declared) {
            return declared;
        }
    }

    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        if ([self lookUp:kNRMAPlatformRules[i].pluginClass with:classLookup]) {
            return [[NRMAPlatformDetection alloc] initWithPlatform:kNRMAPlatformRules[i].platform
                                                   platformVersion:nil
                                                            source:NRMAPlatformDetectionSource_PluginClass];
        }
    }

    for (size_t i = 0; i < kNRMAPlatformRuleCount; i++) {
        for (size_t c = 0; c < 3; c++) {
            if ([self lookUp:kNRMAPlatformRules[i].frameworkClasses[c] with:classLookup]) {
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

+ (Class) lookUp:(const char*)className with:(Class (^)(NSString*))classLookup {
    return className ? classLookup(@(className)) : nil;
}

+ (NRMAPlatformDetection*) declarationOfPluginClass:(Class)pluginClass {
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

@end
