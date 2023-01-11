//
//  NRMATimedTraceSegment.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/1/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATimedTraceSegment.h"

@implementation NRMATimedTraceSegment
- (id) JSONObject {
    NSMutableArray* array = [super JSONObject];
    [array addObject:[NSNumber numberWithLongLong:self.startTime]];
    [array addObject:[NSNumber numberWithLongLong:self.endTime]];
    [array addObject:self.name?:@""];
    
    return array;
}
@end
