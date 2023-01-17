//
//  NRMAHarvesterConnection+GZip.h
//  NewRelicAgent

//  Created by Chris Dillard on 4/18/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvesterConnection.h"

@interface NRMAHarvesterConnection (GZip)

+ (NSData*) gzipData:(NSData*)message;

@end
