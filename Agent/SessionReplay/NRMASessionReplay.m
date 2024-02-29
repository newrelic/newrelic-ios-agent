//
//  NRMASessionReplay.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMASessionReplay.h"
#import "NRLogger.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "NRMAViewDetailProtocol.h"
#import "NRMAUIViewDetails.h"
#import "NRMAUILabelDetails.h"

@implementation NRMASessionReplay {
    UIWindow* _window;
    NSMutableArray<id<NRMAViewDetailProtocol>>* _views;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _views = [[NSMutableArray alloc] init];
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
        
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didBecomeKey)
                                                   name:UIWindowDidBecomeKeyNotification
                                                 object:nil];
    }
    
    return self;
}

- (void)didBecomeVisible {
    NRLOG_AUDIT(@"[SESSION REPLAY] - Window Did Become Visible");
}

// UIApplicationDelegate Notifications

- (void)didEnterBackground {
    NRLOG_AUDIT(@"[SESSION REPLAY] - App did enter background");
}

- (void)didBecomeActive {
    NRLOG_AUDIT(@"[SESSION REPLAY] - App did become active");
    _window = [[UIApplication sharedApplication] keyWindow];
    [self recursiveRecord:_window];
    NSMutableArray<NSDictionary *> *viewDetailJSON = [[NSMutableArray alloc] init];
    for(id<NRMAViewDetailProtocol> detail in _views) {
        NRLOG_AUDIT(@"[SESSION REPLAY] - %@", detail.debugDescription);
        [viewDetailJSON addObject:[detail jsonDescription]];
    }
    
    NSData *viewJSONData = [NSJSONSerialization dataWithJSONObject:viewDetailJSON
                                                           options:0
                                                             error:nil];
    
    NSString *json = [[NSString alloc] initWithData:viewJSONData encoding:NSUTF8StringEncoding];
    NSLog(json);
}

- (void)willEnterForeground {
    NRLOG_AUDIT(@"[SESSION REPLAY] - App did enter foreground");
}

- (void)didBecomeKey {
    NRLOG_AUDIT(@"[SESSION REPLAY] - Window Did Become Key");

}

- (void)recursiveRecord:(UIView *)view {
    id<NRMAViewDetailProtocol> viewToRecord;
    if([view isKindOfClass:[UILabel class]]) {
        viewToRecord = [[NRMAUILabelDetails alloc] initWithView:view];
    } else {
        viewToRecord = [[NRMAUIViewDetails alloc] initWithView:view];
    }
    [_views addObject:viewToRecord];
    for(UIView* subview in view.subviews) {
        [self recursiveRecord:subview];
    }
}

@end
