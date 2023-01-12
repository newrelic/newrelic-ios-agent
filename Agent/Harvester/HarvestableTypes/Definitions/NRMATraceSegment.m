//
//  NRMATraceSegment.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATraceSegment.h"

@implementation NRMATraceSegment
- (id) initWithSegmentType:(NSString*)_type
{
    self = [super init];
    if (self) {
        self.segmentType = _type;
    }
    return self;
}


- (id) JSONObject
{
    NSMutableArray* array = [[NSMutableArray alloc] init];    
    
    return array;
}
@end
