//
//  NRMAExceptionDataCollector.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/1/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NRMAExceptionDataCollectionWrapper.h"
#import "NRMAExceptionMetaDataStore.h"
#import "NRMAReachability.h"
#import <sys/stat.h>

static NRMAExceptionDataCollectionWrapper* __wrapper;

@implementation NRMAExceptionDataCollectionWrapper

- (instancetype) init
{
    self = [super init];
    if (self) {

    }
    return self;
}

+ (NRMAExceptionDataCollectionWrapper*) singleton {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __wrapper = [[NRMAExceptionDataCollectionWrapper alloc] init];
    });

    return __wrapper;
}

+ (void) startCrashMetaDataMonitors
{
    [[[self class] singleton] beginMonitoringOrientation];

}

#pragma mark - orientation observation
- (void) beginMonitoringOrientation
{
#if !TARGET_OS_TV && !TARGET_OS_VISION
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
#endif
}

+ (void) endMonitoringOrientation
{
#if !TARGET_OS_TV && !TARGET_OS_VISION
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
#endif
}

- (void) deviceDidChange:(NSNotification*) notification
{
#if !TARGET_OS_TV && !TARGET_OS_VISION
    if( UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)){
        NRMA_setOrientation("2");
    } else if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
        NRMA_setOrientation("1");
    }
#endif
}

@end

