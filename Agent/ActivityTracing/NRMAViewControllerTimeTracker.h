//
//  NRMAViewControllerTimeTracker.h
//  Agent
//
//  Created by Mike Bruin on 3/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NRTimer.h"
#import "NRConstants.h"

@interface NRMAViewControllerTimeTracker : NSObject

+ (NRTimer*) viewControllerShowingTimer:(UIViewController*) vc;
+ (void) viewControllerShowing:(UIViewController*)vc setTimer:(NRTimer*)timer;

@end
