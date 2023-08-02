//
//  NRMAAnalyticEventProtocol.h
//  Agent
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef NRMAAnalyticEventProtocol_h
#define NRMAAnalyticEventProtocol_h

#import "NRMAJSON.h"

@protocol NRMAAnalyticEventProtocol <NSObject, NRMAJSONABLE>

@property NSTimeInterval timestamp;
@property unsigned long long sessionElapsedTimeSeconds;
@property (nonatomic) NSString *eventType;


- (BOOL) addAttribute:(NSString *)name value:(id)value;
- (NSTimeInterval)getEventAge;

@end

#endif /* NRMAAnalyticEventProtocol_h */
