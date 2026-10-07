//
//  NRMAPreviousSessionHarvestable.h
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAHarvestableArray.h"
#import "NRMADataToken.h"
#import "NRMADeviceInformation.h"

// A standalone harvestable used to send a *previous* session's persisted
// analytics (events + attributes) to the /data endpoint on launch, as a
// dedicated harvest. It mirrors the JSON array shape produced by
// NRMAHarvestData but leaves the metric/transaction/trace nodes empty so the
// post carries only the prior session's analytics tagged with the prior
// session's attributes.
@interface NRMAPreviousSessionHarvestable : NRMAHarvestableArray

- (instancetype) initWithDataToken:(NRMADataToken*)dataToken
                 deviceInformation:(NRMADeviceInformation*)deviceInformation
                        attributes:(NSDictionary*)attributes
                            events:(NSArray*)events;

- (id) JSONObject;

@end
