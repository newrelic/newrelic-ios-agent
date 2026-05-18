//
//  NRMAJSErrorHarvestAdapter.m
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAJSErrorHarvestAdapter.h"

#if TARGET_OS_IOS

#import <NewRelic/NewRelic-Swift.h>

@interface NRMAJSErrorHarvestAdapter ()
@property (nonatomic, strong) JSErrorController* controller;
@end

@implementation NRMAJSErrorHarvestAdapter

- (instancetype)initWithController:(JSErrorController*)controller {
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
