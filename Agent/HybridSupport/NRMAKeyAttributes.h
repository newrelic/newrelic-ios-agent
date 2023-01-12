//
//  NRMAKeyAttributes.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/14/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAgentConfiguration.h"

@interface NRMAKeyAttributes : NSObject
+ (NSDictionary*) keyAttributes:(NRMAConnectInformation*)argument;
@end
