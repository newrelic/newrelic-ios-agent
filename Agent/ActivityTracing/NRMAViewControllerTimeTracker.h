//
//  NRMAViewControllerTimeTracker.h
//  Agent
//
//  Created by Mike Bruin on 3/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NRMAViewControllerTimeTracker : NSObject
- (id) initWithName:(NSString*) string;

+ (NRMAViewControllerTimeTracker*) getViewControllerShowingTracker:(UIViewController*) vc;
+ (void) viewControllerShowing:(UIViewController*)vc setTracker:(NRMAViewControllerTimeTracker*)tracker;
+ (void) removeTrackerFromViewController:(UIViewController*)vc;

- (void) recordViewControllerViewTimeMetric;
@end
