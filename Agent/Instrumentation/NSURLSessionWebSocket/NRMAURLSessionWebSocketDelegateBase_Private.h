//
//  NRMAURLSessionWebSocketDelegateBase_Private.h
//  Agent
//
//  Created by Mike Bruin on 7/19/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAURLSessionWebSocketDelegateBase.h"

@interface NRMAURLSessionWebSocketDelegateBase (private)
- (instancetype) initWithOriginalDelegate:(id<NSURLSessionDelegate>)delegate;
@property (nonatomic, retain, readonly) id<NSURLSessionDataDelegate> realDelegate;


@end
