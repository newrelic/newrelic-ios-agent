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
#import "NRLogger.h"

#import <UIKit/UIKit.h>

static BOOL isPrewarmLaunch = false;
static const NSTimeInterval maxAppLaunchDuration = 180.0;
static const NSTimeInterval maxAppResumeDuration = 60.0;
static NSString* prewarmEnvVar = @"ActivePrewarm";
static NSString* systemBootTimestampKey = @"systemBootTimestamp";

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
    if ([NewRelicInternalUtils isSimulator]) {
        NRLOG_INFO(@"New Relic: Skipping App Start and Resume Time calculation on simulator.");

        return;
    }
    if ([NewRelicInternalUtils isDebuggerAttached]) {
        NRLOG_INFO(@"New Relic: Skipping App Start and Resume Time because debugger is connected.");

        return;
    }

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

    // Based on whether or not we've saved a boot timestamp and whether or not the app has been launched this boot we can determine whether or not this is a warm start.
    NSDate *previousBootTime = [[NSUserDefaults standardUserDefaults] objectForKey:systemBootTimestampKey];
    NSDate* bootTime = self.systemBootTime;
    if (previousBootTime != nil) {
        NSTimeInterval timeSincePreviousBoot = [previousBootTime timeIntervalSinceDate:bootTime];
        if (timeSincePreviousBoot == 0) {
            self.isWarmLaunch = true;
            NRLOG_INFO(@"New Relic: Skipping app start time metric calculation because this is warm start (current system boot time matches previous system boot time.");
        }
    }
    // Save this system boot time to disk.
    [[NSUserDefaults standardUserDefaults] setObject:bootTime forKey:systemBootTimestampKey];

    // For now we'll skip recording active prewarm launches since in iOS 15+ we can't be sure it wasn't warmed long before user started app.
    // Since in iOS 15 the OS may launch apps before the user selects them. (This would create app launch times of minutes or even days.)
    if (([self isPrewarmAvailable] && isPrewarmLaunch) && self.isWarmLaunch) {
        NRLOG_INFO(@"New Relic: Skipping App Start Time because iOS prewarmed this launch.");

        return;
    }
    if (self.isWarmLaunch) {
        NRLOG_INFO(@"New Relic: Skipping App Start Time because matching boot times.");
        return;
    }

    // If the app was running in the background. Skip recording this launch.
    if (self.wasInBackground) {
        return;
    }

    // App Launch Time: Cold is time between now and when process started.
    NSTimeInterval calculatedAppLaunchDuration = [[NSDate date] timeIntervalSinceDate:self.processStartTime];

    // Skip recording obviously wrong extra long app launch durations.
    if (calculatedAppLaunchDuration >= maxAppLaunchDuration) {
        NRLOG_INFO(@"New Relic: Skipping app start time metric since %f > allowed.", calculatedAppLaunchDuration);
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
    if (self.wasInBackground && self.willEnterForegroundTimestamp != nil) {
        NSTimeInterval calculatedAppResumeDuration = [[NSDate date] timeIntervalSinceDate:self.willEnterForegroundTimestamp];

        if (calculatedAppResumeDuration >= maxAppResumeDuration) {
            NRLOG_INFO(@"New Relic: Skipping app start resume (Hot launch) metric since %f > allowed.", calculatedAppResumeDuration);
            return;
        }

        self.appResumeDuration = calculatedAppResumeDuration;
        self.wasInBackground = false;
        self.willEnterForegroundTimestamp = nil;
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

- (NSDate *)systemBootTime {
    struct timeval bootTime = timeVal(CTL_KERN, KERN_BOOTTIME);
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:bootTime.tv_sec + bootTime.tv_usec / 1E6];
    return date;
}

@end
