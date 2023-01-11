//
//  NRMATraceSegment.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/12/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestableArray.h"
#import "NRMAThreadInfo.h"
@interface NRMATraceSegment : NRMAHarvestableArray
@property(nonatomic,strong) NSString* segmentType;


- (id) initWithSegmentType:(NSString*)_type;
@end
