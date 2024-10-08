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
    NRMAUIViewDetails * _rootView;
    
//    NSMutableArray<NSDictionary *>* _frames;
    NSMutableArray<NRMAUIViewDetails *>* _rawFrames;
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
}

-(NSDictionary *)generateInitialNode {
    return @{@"type" : @(4), @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000), @"data": @{@"href": @"http://newrelic.com", @"width": @(_window.windowScene.screen.bounds.size.width /** _window.windowScene.screen.scale*/), @"height" : @(_window.windowScene.screen.bounds.size.height /** _window.windowScene.screen.scale*/)}};
}

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
    NSArray<NRMAUIViewDetails *>* frameData = [_sessionReplayCapture recordFromRootView:_window];
    NRMASessionReplayFrame* frame = [[NRMASessionReplayFrame alloc] initWithTimestamp:[NSDate now] andNodes:frameData];
    [_processedFrames addObject:[_sessionReplayFrameProcessor process:frame]];

    frameCount++;
    NSLog(@"Captured frame %d", frameCount);
    
    if(frameCount == 10) {
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

@end
