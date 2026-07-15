//
//  NRMAMobileErrorHarvestAdapter.m
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAMobileErrorHarvestAdapter.h"

#if TARGET_OS_IOS

#import <NewRelic/NewRelic-Swift.h>

@interface NRMAMobileErrorHarvestAdapter ()
@property (nonatomic, strong) MobileErrorController* controller;
@end

@implementation NRMAMobileErrorHarvestAdapter

- (instancetype)initWithController:(MobileErrorController*)controller {
    self = [super init];
    if (self) {
        _controller = controller;
    }
    return self;
}

- (void)onHarvestStart {
    [self.controller onHarvestStart];
}

- (void)onHarvestBefore {
    [self.controller onHarvestBefore];
}

- (void)onHarvest {
    [self.controller onHarvest];
}

- (void)onHarvestComplete {
    [self.controller onHarvestComplete];
}

- (void)onHarvestError {
    [self.controller onHarvestError];
}

- (void)onHarvestStop {
    [self.controller onHarvestStop];
}

- (void)onHarvestConnected {
    [self.controller onHarvestConnected];
}

- (void)onHarvestDisconnected {
    [self.controller onHarvestDisconnected];
}

@end

#endif // TARGET_OS_IOS
