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
#import "NRMAIdGenerator.h"
#import "NRMASessionReplayFrame.h"
#import "NRMASessionReplayCapture.h"
#import "NRMASessionReplayFrameProcessor.h"

@interface NRMASessionReplayContext : NSObject

@property (nonatomic, strong) NSString* sessionID;
@property (nonatomic, strong) NSString* viewID;

@end


@implementation NRMASessionReplay {
    UIWindow* _window;
//    NSMutableArray<id<NRMAViewDetailProtocol>>* _views;
    id<NRMAViewDetailProtocol> _rootView;
    
//    NSMutableArray<NSDictionary *>* _frames;
    NSMutableArray<id<NRMAViewDetailProtocol>>* _rawFrames;
    NSMutableArray<NSDictionary *>* _processedFrames;
    NSMutableArray<NSString *>* _styles;
    int frameCount;
    NSTimer* _frameTimer;
    NSTimer* _screenChangeTimer;
    
    NRMASessionReplayCapture* _sessionReplayCapture;
    NRMASessionReplayFrameProcessor* _sessionReplayFrameProcessor;
}

- (instancetype)init {
    self = [super init];
    if(self) {
//        _views = [[NSMutableArray alloc] init];
        _rootView = nil;
        _rawFrames = [[NSMutableArray alloc] init];
        _styles = [NSMutableArray new];
        _processedFrames = [NSMutableArray new];
        frameCount = 0;
        
        _sessionReplayCapture = [[NRMASessionReplayCapture alloc] init];
        _sessionReplayFrameProcessor = [[NRMASessionReplayFrameProcessor alloc] init];
        
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
    self->_window = [[UIApplication sharedApplication] keyWindow];

    [_processedFrames addObject:[self generateInitialNode]];
    _frameTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self takeFrame];
    }];
    
//    _screenChangeTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        self->_window = [[UIApplication sharedApplication] keyWindow];
//        UIViewController* contentViewController = self->_window.rootViewController;
//        
//        if([contentViewController isKindOfClass:[UINavigationController class]]) {
//            contentViewController = ((UINavigationController*)contentViewController).visibleViewController;
//        } else if ([contentViewController isKindOfClass:[UITabBarController class]]) {
//            contentViewController = ((UITabBarController*)contentViewController).selectedViewController;
//        }
//        
//        NRLOG_AUDIT(@"Current View Controller: %@", contentViewController.description);
//    }];
}

-(NSDictionary *)generateInitialNode {
    return @{@"type" : @(4), @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"data": @{@"href": @"http://newrelic.com", @"width": @(_window.windowScene.screen.bounds.size.width /** _window.windowScene.screen.scale*/), @"height" : @(_window.windowScene.screen.bounds.size.height /** _window.windowScene.screen.scale*/)}};
}

//- (NSDictionary *)generateStyleNode {
//    NSString *styleTextString = [_styles componentsJoinedByString:@"\n"];
//
//    NSDictionary *styleNode = @{@"type": @(2), @"tagName": @"style", @"attributes": @{}, @"id": @([NRMAIdGenerator generateID]), @"childNodes" : @[@{@"type": @"Text", @"textContent": styleTextString}]};
//    return styleNode;
//}

- (void)willEnterForeground {
    NRLOG_AUDIT(@"[SESSION REPLAY] - App did enter foreground");
}

- (void)didBecomeKey {
    NRLOG_AUDIT(@"[SESSION REPLAY] - Window Did Become Key");
}

- (void)takeFrame {
    if(_rootView) {
        [_rawFrames addObject:_rootView];
        _rootView = nil;
    }
    
    _window = [[UIApplication sharedApplication] keyWindow];
    NSArray<Node>* frameData = [_sessionReplayCapture recordFromRootView:_window];
    NRMASessionReplayFrame* frame = [[NRMASessionReplayFrame alloc] initWithTimestamp:[NSDate now] andNodes:frameData];
    [_processedFrames addObject:[_sessionReplayFrameProcessor process:frame]];

    frameCount++;
    
    if(frameCount == 2) {
        [_frameTimer invalidate];

        NSString* frameJSON = [self consolidateFrames];
        NSLog(frameJSON);
    }
}

- (NSString *)consolidateFrames {
    NSData *viewFramesJSONData = [NSJSONSerialization dataWithJSONObject:_processedFrames
                                                                 options:0
                                                                   error:nil];
    NSString *frameJSON = [[NSString alloc] initWithData:viewFramesJSONData encoding:NSUTF8StringEncoding];
    return frameJSON;
}

- (BOOL)shouldRecordView:(UIView *)view {
    UIView* superview = view.superview;
    
    if(superview == nil) {
        return YES;
    }
    
    BOOL areFramesTheSame = CGRectEqualToRect(view.frame, superview.frame);
    BOOL isClear = (view.alpha == 0 || view.alpha == 1);
    
    if(areFramesTheSame && isClear) {
        return NO;
    }
    
    return YES;
}

@end
