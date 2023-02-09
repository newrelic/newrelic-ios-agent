//
//  NRMAAppToken.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/19/18.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAAppToken : NSObject

/*
 * @property: token
 * represents the true New Relic application token provided by the customer
 *
 * @property: regionCode
 * the region code used to identify the sub-domain for collector address on region-aware tokens
 */
@property (readonly, strong) NSString* value;
@property (readonly, strong) NSString* regionCode;

- (instancetype) initWithApplicationToken:(NSString*)appToken;

@end
