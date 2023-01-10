//
//  NRMAHarvestableHTTPErrors.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvestableArray.h"
#import "NRMAHarvestableHTTPError.h"
#import "NRMAHarvestAware.h"
#define kNRMAStoreHTTPErrorNotification @"com.newrelic.storeHTTPError"
@interface NRMAHarvestableHTTPErrors : NRMAHarvestableArray <NRMAHarvestAware>
{
    NSMutableDictionary*  httpErrors;
}


- (void) addHTTPError:(NRMAHarvestableHTTPError*)error;
- (void) clear;
@end
