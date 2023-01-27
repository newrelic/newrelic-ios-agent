	//
//  NSURLSessionTaskDelegateBase.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/1/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRURLSessionTaskDelegateBase.h"
@interface NRURLSessionTaskDelegateBase (private)
- (instancetype) initWithOriginalDelegate:(id<NSURLSessionDelegate>)delegate;
@property (nonatomic, retain, readonly) id<NSURLSessionDataDelegate> realDelegate;


@end
