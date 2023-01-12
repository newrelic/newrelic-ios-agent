//
// Created by Bryce Buchanan on 1/14/16.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>


/*
    this Class instruments sendAction:to:from:forEvent: on UIApplication
    for generating TrackedGestures.
 */


@interface NRMAApplicationInstrumentation : NSObject
+ (BOOL) instrumentUIApplication;
+ (BOOL) deinstrumentUIApplication;
@end
