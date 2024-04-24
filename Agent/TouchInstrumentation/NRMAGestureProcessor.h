//
//  NRMAGestureProcessor.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/11/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*
 * This object provides an simplified interface to collect key details from
 * UIControl objects and UIEvents which are used in TrackedGesture Events.
 */

@interface NRMAGestureProcessor : NSObject
+ (NSString*) getLabel:(id)control;
+ (NSString*) getResponderChain:(id)control;
+ (NSString*) getAccessibility:(id)control;
#if !TARGET_OS_WATCH
+ (NSString*) getTouchCoordinates:(UIEvent*)event;
#endif
+ (NSString*) getFrame:(id)control;
@end
