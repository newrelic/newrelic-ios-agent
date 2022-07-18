//
//  NRMASupportMetricHelper.h
//  Agent
//
//  Created by Chris Dillard on 7/12/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMASupportMetricHelper : NSObject

+ (void) enqueueDataUseMetric:(NSString*)subDestination size:(long)size received:(long)received;

@end
