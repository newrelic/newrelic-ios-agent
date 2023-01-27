//
//  NRMAStartTimer.h
//  Agent
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

@interface NRMAStartTimer: NSObject

@property (nonatomic) NSTimeInterval appLaunchDuration;
@property (nonatomic) NSTimeInterval appResumeDuration;
@property (nonatomic) BOOL isWarmLaunch;

+ (NRMAStartTimer *)sharedInstance;

- (void)start;

@end
