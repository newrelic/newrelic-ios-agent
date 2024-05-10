//
//  NRMAWKApplicationDelegateBase.m
//  Agent-watchOS
//
//  Created by Mike Bruin on 5/8/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAWKApplicationDelegateBase.h"
#import <WatchKit/WatchKit.h>


@class WKApplication;
@protocol WKApplicationDelegate;

@implementation NRMAWKApplicationDelegateBase

- (instancetype _Nullable) initWithOriginalDelegate:(id<WKApplicationDelegate>_Nonnull)delegate{
    self = [super init];
    if (self) {
        _realDelegate = delegate;
    }
    return self;
}

- (void) applicationDidFinishLaunching {
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate performSelector:@selector(applicationDidFinishLaunching)];
    }
}

- (void) applicationWillResignActive {
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate performSelector:@selector(applicationWillResignActive)];
    }
}

- (void) applicationDidEnterBackground {
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate performSelector:@selector(applicationDidEnterBackground)];
    }
}

- (void) applicationWillEnterForeground {
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate performSelector:@selector(applicationWillEnterForeground)];
    }
}

@end
