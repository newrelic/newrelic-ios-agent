//
// Created by Bryce Buchanan on 2/9/15.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvestableArray.h"
#import "NRMAHarvestAware.h"

@interface NRMAAnalyticsEvents :  NRMAHarvestableArray <NRMAHarvestAware>
@property(atomic,retain) NSMutableArray* events;
- (void) clear;
- (NSUInteger) count;
// Array of dictionaries
- (void) addEvents:(NSArray*) events;
@end
