//
//  NRMAStartTimer.m
//  Agent
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAStartTimer.h"
#import "NRMASysctlBinding.h"
#import "NewRelicInternalUtils.h"
#include <stdio.h>
#include <time.h>

#import <UIKit/UIKit.h>

static BOOL isPrewarmLaunch = false;
static const NSTimeInterval maxAppLaunchDuration = 180.0;
static const NSTimeInterval maxAppResumeDuration = 60.0;
static NSString* prewarmEnvVar = @"ActivePrewarm";

@interface
NRMAStartTimer ()
@property (nonatomic, assign) BOOL wasInBackground;
@property (nonatomic, strong) NSDate *willEnterForegroundTimestamp;
@end

static NRMAStartTimer *_sharedInstance;

@implementation NRMAStartTimer

+ (void)load {
    //This env var is removed after the DidFinishLaunchingNotification, must be checked in load.
    isPrewarmLaunch = [[NSProcessInfo processInfo].environment[prewarmEnvVar] isEqual:@"1"];
}

+ (BOOL) isSimulator {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *environment = [processInfo environment];
    NSString *simulator = [environment objectForKey:@"SIMULATOR_DEVICE_NAME"];
    return simulator != nil;
}

+ (NRMAStartTimer *) sharedInstance {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _sharedInstance = [[NRMAStartTimer alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.wasInBackground = NO;
    }

    return self;
}

- (void)start {

    // Skip app start timing if running on simulator or debugger attached.
    if ([NRMAStartTimer isSimulator]) { return; }
    if ([NewRelicInternalUtils isDebuggerAttached]) { return; }

    // This is used as "first draw" timestamp in the "time to first draw" calculation.
    // UIWindow Notifications
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeVisible)
                                               name:UIWindowDidBecomeVisibleNotification
                                             object:nil];
    // UIApplication Notifications
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willEnterForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
}

- (void)createDurationMetric {

    // For now we'll skip recording active prewarm launches since in iOS 15+ we can't be sure it wasn't warmed long before user started app.
    // Since in iOS 15 the OS may launch apps before the user selects them. (This would create app launch times of minutes or even days.)
    if ([self isPrewarmAvailable] && isPrewarmLaunch) { return; }

    // If the app was running in the background. Skip recording this launch.
    if (self.wasInBackground) { return; }

    // App Launch Time: Cold is time between now and when process started.
    NSTimeInterval calculatedAppLaunchDuration = [[NSDate date] timeIntervalSinceDate:self.processStartTime];

    // Skip recording obviously wrong extra long app launch durations.
    if (calculatedAppLaunchDuration >= maxAppLaunchDuration) {
        return;
    }

    self.appLaunchDuration = calculatedAppLaunchDuration;
}

- (BOOL)isPrewarmAvailable {
    if (@available(iOS 14, *)) {
        return YES;
    }
    else {
        return NO;
    }
}

// UIWindow Notifications

- (void)didBecomeVisible {
    [self createDurationMetric];
}

// UIApplicationDelegate Notifications

- (void)didEnterBackground {
    self.wasInBackground = YES;
}

- (void)didBecomeActive {

    if (self.wasInBackground) {
        NSTimeInterval calculatedAppResumeDuration = [[NSDate date] timeIntervalSinceDate:self.willEnterForegroundTimestamp];

        if (calculatedAppResumeDuration >= maxAppResumeDuration) {
            return;
        }

        self.appResumeDuration = calculatedAppResumeDuration;
    }
}

- (void)willEnterForeground {
    self.willEnterForegroundTimestamp = [NSDate date];
}

// Sysctl

- (NSDate *)processStartTime {
    struct timeval processStart = processStartTime();
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:processStart.tv_sec + processStart.tv_usec / 1E6];
    return date;
}

@end
