//
//  NRMABase64.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/29/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NRMABase64 : NSObject

+ (NSString*) encodeFromData:(NSData*)data;

@end
