//
//  NRMAHarvesterConnection+GZip.h
//  NewRelicAgent

//  Created by Chris Dillard on 4/18/22.
//  Copyright (c) 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvesterConnection.h"

@interface NRMAHarvesterConnection (GZip)

+ (NSData*) gzipData:(NSData*)message;

@end
