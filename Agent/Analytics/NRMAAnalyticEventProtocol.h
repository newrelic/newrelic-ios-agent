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

@protocol NRMAAnalyticEventProtocol <NSObject, NRMAJSONABLE, NSSecureCoding>

@property (readonly, nonatomic, strong) NSNumber *timestamp;
@property (readonly, nonatomic, strong) NSNumber *sessionElapsedTimeSeconds;
@property (nonatomic, strong) NSString *eventType;
@property (strong) NSMutableDictionary<NSString *, id> *attributes;

- (BOOL) addAttribute:(NSString *)name value:(id)value;
- (NSTimeInterval)getEventAge;

@end

#endif /* NRMAAnalyticEventProtocol_h */
