//
//  NRMAURLSessionWebSocketDelegateBase.h
//  Agent
//
//  Created by Mike Bruin on 7/20/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
//@protocol WKNavigationDelegate;

@interface NRMAURLSessionWebSocketDelegateBase : NSObject // <URLSessionWebSocketDelegate>
@property(weak, nullable) NSObject* realDelegate;

@end
