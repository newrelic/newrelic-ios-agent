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
#import <objc/runtime.h>
#import <objc/message.h>

#import "NRMAUIViewDetails.h"
#import "NRMAUILabelDetails.h"
#import "NRMAIdGenerator.h"
#import "NRMASessionReplayFrame.h"
#import "NRMASessionReplayCapture.h"
#import "NRMASessionReplayFrameProcessor.h"
#import "NRMAMethodSwizzling.h"
#import <NewRelic/NewRelic-Swift.h>

IMP NRMAOriginal__sendEvent;

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
    NRMASessionReplayTouchCapture* _touchCapture;
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

- (void)swizzleSendEvent {
    id clazz = objc_getClass("UIApplication");
    if(clazz) {
//        NRMAOriginal__sendEvent = NRMAReplaceInstanceMethod(clazz, @selector(sendEvent:), (IMP)NRMAOverride__sendEvent);
        SEL originalSendEventSel = @selector(sendEvent:);
        NRMAOriginal__sendEvent = NRMAReplaceInstanceMethod(clazz, @selector(sendEvent:), imp_implementationWithBlock(^(__unsafe_unretained UIApplication *self_, UIEvent* event) {
//            NSLog(@"Touch Swizzle. Event: %@", event);

//            va_end(argp);
//            NSLog(@"Event: %@", [event description]);
            [self->_touchCapture captureSendEventTouchesWithEvent:event];
            IMP originalImp = NRMAOriginal__sendEvent;
            
            ((void (*)(id, SEL, UIEvent*))originalImp)(self_, originalSendEventSel, event);
        }));
//        SEL originalSendEventSel = @selector(sendEvent:);
//        const Method method = class_getInstanceMethod(clazz, originalSendEventSel);
//        if(!method) {
//            NSLog(@"Unable to get sendEvent: in %@", NSStringFromClass(clazz));
//        } else {
//            const char *types = method_getTypeEncoding(method);
//            BOOL success = class_addMethod(clazz, originalSendEventSel, imp_implementationWithBlock(^(__unsafe_unretained id self_, UIEvent *event) {
//                struct objc_super super = {self_, clazz};
//                return ((id(*)(struct objc_super *, SEL, UIEvent*))objc_msgSendSuper)(&super, originalSendEventSel, event);
//
//            }), types);
//            NSLog(@"Class AddMethod success = %d", success);
//            __block IMP originalSendEventIMP = class_replaceMethod(clazz, originalSendEventSel, imp_implementationWithBlock(^(__unsafe_unretained id self_, UIEvent *event) {
////                NSLog(@"Touch Swizzle. Event: %@", event);
////                [self->_touchCapture captureSendEventTouchesWithEvent:event];
//                ((void (*)(id, SEL, UIEvent*))originalSendEventIMP)(self_, originalSendEventSel, event);
//            }), types);
//        }
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
    _touchCapture = [[NRMASessionReplayTouchCapture alloc] initWithWindow:_window];
    [_processedFrames addObject:[self generateInitialNode]];
    _frameTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        [self takeFrame];
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

void NRMAOverride__sendEvent(id self_, SEL _cmd, UIEvent* event) {
    NSLog(@"Touch Swizzle. Event: %@", event);
    
//    UIView* view = []
    
    IMP originalImp = NRMAOriginal__sendEvent;
    
   ((id(*)(id, SEL, UIEvent*))originalImp)(self_, _cmd, event);
}

@end

