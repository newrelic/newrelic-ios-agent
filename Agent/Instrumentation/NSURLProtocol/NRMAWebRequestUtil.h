//
//  NRMAWebRequestUtil.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 7/19/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAWebRequestUtil : NSObject
+ (BOOL) isWebViewRequest:(NSURLRequest*)request;
+ (NSMutableURLRequest*) setIsWebViewRequest:(NSURLRequest*)request;
+ (NSMutableURLRequest*) clearIsWebViewRequest:(NSURLRequest*)request;
@end
