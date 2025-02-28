//
//  NRMASessionReplay.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMASessionReplayObjC.h"
#import "NRLogger.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "NRMAUIViewDetailsObjC.h"
#import "NRMAUILabelDetailsObjC.h"
#import "NRMAIdGeneratorObjC.h"
#import "NRMASessionReplayFrameObjC.h"
#import "NRMASessionReplayCaptureObjC.h"
#import "NRMASessionReplayFrameProcessorObjC.h"
#import "NRMAMethodSwizzling.h"
#import "NRMAAssociate.h"
#import <NewRelic/NewRelic-Swift.h>

@interface NRMATouch : NSObject

@property (readonly, nonatomic) NSDate* timestamp;
@property (readonly, assign) CGPoint touchLocation;
@property (readonly, assign) NSUInteger identifier;

- (instancetype)initWithTimestamp:(NSDate *)timestamp andLocation:(CGPoint)location andIdentifier: (NSUInteger)identifier;

@end

@implementation NRMATouch

- (instancetype)initWithTimestamp:(NSDate *)timestamp andLocation:(CGPoint)location andIdentifier:(NSUInteger)identifier {
    self = [super init];
    if(self) {
        _timestamp = timestamp;
        _touchLocation = location;
        _identifier = identifier;
    }
    
    return self;
}

@end

@interface  NRMATouchTracker : NSObject

@property (readonly, nonatomic) NRMATouch* startTouch;
@property (nonatomic) NSMutableArray<NRMATouch *>* moveTouches;
@property (nonatomic) NRMATouch* endTouch;

-(instancetype)initWithStartTouch:(NRMATouch*)startTouch;
-(void)addMoveTouch:(NRMATouch*)moveTouch;
-(void)addEndTouch:(NRMATouch*)endTouch;

@end

@implementation NRMATouchTracker

-(instancetype)initWithStartTouch:(NRMATouch *)startTouch {
    self = [super init];
    if(self) {
        _startTouch = startTouch;
        _moveTouches = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)addMoveTouch:(NRMATouch *)moveTouch {
    [_moveTouches addObject:moveTouch];
}

- (void)addEndTouch:(NRMATouch *)endTouch {
    _endTouch = endTouch;
}

- (NSArray *) jsonDescription {
    NSMutableArray *touchDescriptions = [[NSMutableArray alloc] init];
    
    NSDictionary *startTouchDescription = @{ @"type": @(3),
                                             @"timestamp": @([_startTouch.timestamp timeIntervalSince1970] * 1000),
                                             @"data": @{
                                                 @"source": @(2),
                                                 @"type": @(7),
                                                 @"pointerType": @(2),
                                                 @"id": @(_startTouch.identifier),
                                                 @"x": @(_startTouch.touchLocation.x),
                                                 @"y": @(_startTouch.touchLocation.y)
                                             }};
    
    [touchDescriptions addObject:startTouchDescription];
    
    if(!(self.moveTouches.count == 0)) {
        NSMutableArray* positions = [NSMutableArray new];
        NSDate* initialDate = self.moveTouches.firstObject.timestamp;
        
        for(NRMATouch *touchDescription in self.moveTouches) {
            NSTimeInterval timeInterval = [touchDescription.timestamp timeIntervalSinceDate:initialDate];
            [positions addObject:@{ @"id": @(touchDescription.identifier),
                                    @"x": @(touchDescription.touchLocation.x),
                                    @"y": @(touchDescription.touchLocation.y),
                                    @"timeOffset": @(timeInterval)}];
        }
        
        NSDictionary *moveTouchDescription = @{ @"type": @(3),
                                                 @"timestamp": @([initialDate timeIntervalSince1970] * 1000),
                                                 @"data": @{
                                                     @"source": @(6),
                                                     @"positions": positions
                                                 }};
        [touchDescriptions addObject:moveTouchDescription];
    }
    
//    for(NRMATouch *touchDescription in _moveTouches) {
//        NSTimeInterval timeInterval = [touchDescription.timestamp timeIntervalSinceDate:self.startTouch.timestamp];
//        
//        NSDictionary *moveTouchDescription = @{ @"type": @(3),
//                                                 @"timestamp": @([touchDescription.timestamp timeIntervalSince1970]),
//                                                 @"data": @{
//                                                     @"source": @(1),
//                                                     @"positions": @[@{
//                                                         @"id": @(touchDescription.identifier),
//                                                         @"x": @(touchDescription.touchLocation.x),
//                                                         @"y": @(touchDescription.touchLocation.y),
//                                                         @"timeOffset": @(timeInterval)
//                                                     }]
//                                                 }};
//        [touchDescriptions addObject:moveTouchDescription];
//    }
    
    NSDictionary *endTouchDescription = @{ @"type": @(3),
                                             @"timestamp": @([_endTouch.timestamp timeIntervalSince1970] * 1000),
                                             @"data": @{
                                                 @"source": @(2),
                                                 @"type": @(9),
                                                 @"id": @(_endTouch.identifier),
                                                 @"x": @(_endTouch.touchLocation.x),
                                                 @"y": @(_endTouch.touchLocation.y)
                                             }};
    
    [touchDescriptions addObject:endTouchDescription];
    
    return touchDescriptions;
}


@end


IMP NRMAOriginal__sendEvent;

@interface NRMASessionReplayContext : NSObject

@property (nonatomic, strong) NSString* sessionID;
@property (nonatomic, strong) NSString* viewID;

@end

@implementation NRMASessionReplayObjC {
    UIWindow* _window;
//    NSMutableArray<id<NRMAViewDetailProtocol>>* _views;
    NRMAUIViewDetailsObjC * _rootView;
    
//    NSMutableArray<NSDictionary *>* _frames;
    NSMutableArray<NRMAUIViewDetailsObjC *>* _rawFrames;
    NSMutableArray<NSDictionary *>* _processedFrames;
    NSMutableArray<NSString *>* _styles;
    int frameCount;
    NSTimer* _frameTimer;
    NSTimer* _screenChangeTimer;
    
    NRMASessionReplayCaptureObjC* _sessionReplayCapture;
    NRMASessionReplayFrameProcessorObjC* _sessionReplayFrameProcessor;
    SessionReplayTouchCapture* _touchCapture;
    
    NSUInteger touchID;
    NSMutableArray<NRMATouchTracker*>* _trackedTouches;
}

- (instancetype)init {
    self = [super init];
    if(self) {
//        _views = [[NSMutableArray alloc] init];
        _rootView = nil;
        _rawFrames = [[NSMutableArray alloc] init];
        _styles = [NSMutableArray new];
        _processedFrames = [NSMutableArray new];
        _trackedTouches = [[NSMutableArray alloc] init];
        frameCount = 0;
        touchID = 0;
        
        _sessionReplayCapture = [[NRMASessionReplayCaptureObjC alloc] init];
        _sessionReplayFrameProcessor = [[NRMASessionReplayFrameProcessorObjC alloc] init];
        
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

- (void)swizzleSendEvent {
    id clazz = objc_getClass("UIApplication");
    if(clazz) {
        SEL originalSendEventSel = @selector(sendEvent:);
        NRMAOriginal__sendEvent = NRMAReplaceInstanceMethod(clazz, @selector(sendEvent:), imp_implementationWithBlock(^(__unsafe_unretained UIApplication *self_, UIEvent* event) {
//            NSLog(@"Touch Swizzle. Event: %@", event);

//            va_end(argp);
//            NSLog(@"Event: %@", [event description]);
//            [self->_touchCapture captureSendEventTouchesWithEvent:event];
            for(UITouch *touch in event.allTouches) {

                if(touch.phase == UITouchPhaseBegan) {
                    self->touchID++;
                    NRMATouch *nrmaTouch = [[NRMATouch alloc] initWithTimestamp:[NSDate date]
                                                                    andLocation:[touch locationInView:touch.window] andIdentifier: self->touchID];
                    NRMATouchTracker *touchTracker = [[NRMATouchTracker alloc]initWithStartTouch:nrmaTouch];
                    [NRMAAssociate attach:touchTracker to:touch with:@"TouchTracker"];
                } else if(touch.phase == UITouchPhaseMoved) {
                    NRMATouchTracker *touchTracker = [NRMAAssociate retrieveFrom:touch with:@"TouchTracker"];
                    if(touchTracker == nil) {
                        NSLog(@"ERROR: Touch Tracker didn't associate with touch!");
                    } else {
                        NRMATouch *nrmaTouch = [[NRMATouch alloc] initWithTimestamp:[NSDate date]
                                                                        andLocation:[touch locationInView:touch.window] andIdentifier: self->touchID];
                        [touchTracker addMoveTouch:nrmaTouch];
                    }
                } else if(touch.phase == UITouchPhaseEnded){
                    NRMATouchTracker *touchTracker = [NRMAAssociate retrieveFrom:touch with:@"TouchTracker"];
                    if(touchTracker == nil) {
                        NSLog(@"ERROR: Touch Tracker didn't associate with touch!");
                    } else {
                        NRMATouch *nrmaTouch = [[NRMATouch alloc] initWithTimestamp:[NSDate date]
                                                                        andLocation:[touch locationInView:touch.window] andIdentifier: self->touchID];
                        [touchTracker addEndTouch:nrmaTouch];
                        [self->_trackedTouches addObject:touchTracker];
                    }
                }
            }
            
            IMP originalImp = NRMAOriginal__sendEvent;
            
            ((void (*)(id, SEL, UIEvent*))originalImp)(self_, originalSendEventSel, event);
        }));

    }
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
    [self swizzleSendEvent];
    _touchCapture = [[SessionReplayTouchCapture alloc] initWithWindow:_window];
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

    NSArray<NRMAUIViewDetailsObjC *>* frameData = [_sessionReplayCapture recordFromRootView:_window];
    NRMASessionReplayFrameObjC* frame = [[NRMASessionReplayFrameObjC alloc] initWithTimestamp:[NSDate now] andNodes:frameData];
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
    [self processTouches];
    
    NSData *viewFramesJSONData = [NSJSONSerialization dataWithJSONObject:_processedFrames
                                                                 options:0
                                                                   error:nil];
    NSString *frameJSON = [[NSString alloc] initWithData:viewFramesJSONData encoding:NSUTF8StringEncoding];
    return frameJSON;
}

- (void)processTouches {
    for (NRMATouchTracker *touchTracker in _trackedTouches) {
        NSArray* touch = [touchTracker jsonDescription];
        [_processedFrames addObjectsFromArray:touch];
    }
}

@end

