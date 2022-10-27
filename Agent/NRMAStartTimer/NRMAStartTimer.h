//
//  NRMAStartTimer.h
//  Agent
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

@interface NRMAStartTimer: NSObject

// Cold launch
@property (nonatomic) NSTimeInterval appLaunchDuration;
// Hot launch
@property (nonatomic) NSTimeInterval appResumeDuration;
// Warm launch
@property (nonatomic) NSTimeInterval warmAppLaunchDuration;
// Extended launch
@property (nonatomic) NSTimeInterval extendedAppLaunchDuration;

@property (nonatomic) BOOL isWarmLaunch;

+ (NRMAStartTimer *)sharedInstance;

- (void)start;

@end
