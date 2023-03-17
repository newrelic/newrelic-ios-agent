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

#define kNRUIViewControllerTimerAssocObject @"com.NewRelic.UIViewController.Timer"

@interface NRMAViewControllerTimeTracker()

@end

@implementation NRMAViewControllerTimeTracker


+ (NRTimer*) viewControllerShowingTimer:(UIViewController*) vc
{
    if(vc == nil) return nil;
    
    return objc_getAssociatedObject(vc, kNRUIViewControllerTimerAssocObject);
}

+ (void) viewControllerShowing:(UIViewController*)vc setTimer:(NRTimer*)timer {
    if(vc == nil) return;
    
    objc_AssociationPolicy assocPolicy = OBJC_ASSOCIATION_RETAIN;
    if (timer == nil) {
        assocPolicy = OBJC_ASSOCIATION_ASSIGN;
    }
    objc_setAssociatedObject(vc, kNRUIViewControllerTimerAssocObject, timer, assocPolicy);
}

@end
