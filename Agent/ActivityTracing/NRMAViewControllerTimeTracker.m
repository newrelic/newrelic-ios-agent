//
//  NRMAViewControllerTimeTracker.m
//  Agent
//
//  Created by Mike Bruin on 3/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "NRMAViewControllerTimeTracker.h"
#import "NRMAMeasurements.h"
#import "NRMAAssociate.h"

#define kNRUIViewControllerTimerAssocObject @"com.NewRelic.UIViewController.TimeTracker"

@interface NRMAMeasurements (private) //methods only used by NRMATaskQueue
+ (void)recordMetric:(NRMAMetric *)metric;
@end

@interface NRMAViewControllerTimeTracker()
@property(strong) NSString *name;
@property(strong) NRTimer *timer;
- (void) applicationWillEnterForeground;
- (void) applicationDidEnterBackground;

@end

@implementation NRMAViewControllerTimeTracker

- (id) initWithName:(NSString*) string
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        self.timer = [[NRTimer alloc] init];
        self.name = string;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    self.name = nil;
    self.timer = nil;
}

- (void) applicationDidEnterBackground
{
    [self recordViewControllerViewTimeMetric];
}

- (void) applicationWillEnterForeground
{
    self.timer = [[NRTimer alloc] init];
}

- (void) recordViewControllerViewTimeMetric
{
    NSString* name = self.name;
    if (name == NULL || self.timer == NULL) {
        return;
    }

    NRTimer* tempTimer = self.timer;
    self.timer = nil;
    [tempTimer stopTimer];

    [NRMAMeasurements recordMetric:[[NRMAMetric alloc] initWithName:[[NSString alloc] initWithFormat:@"Mobile/Activity/Name/View_Time %@", name] value:[[NSNumber alloc]initWithDouble:tempTimer.timeElapsedInSeconds] scope:name produceUnscoped:YES additionalValue:nil]];
}

+ (NRMAViewControllerTimeTracker*) getViewControllerShowingTracker:(UIViewController*) vc
{
    return [NRMAAssociate retrieveFrom:vc with:kNRUIViewControllerTimerAssocObject];
}

+ (void) viewControllerShowing:(UIViewController*)vc setTracker:(NRMAViewControllerTimeTracker*)tracker
{
    [NRMAAssociate attach:tracker to:vc with:kNRUIViewControllerTimerAssocObject];
}

+ (void) removeTrackerFromViewController:(UIViewController*)vc
{
    [NRMAAssociate removeFrom:vc with:kNRUIViewControllerTimerAssocObject];
}

@end
