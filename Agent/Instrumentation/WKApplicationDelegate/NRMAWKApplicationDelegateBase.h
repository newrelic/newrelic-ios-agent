//
//  NRMAWKApplicationDelegateBase.m
//  Agent-watchOS
//
//  Created by Mike Bruin on 5/8/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <WatchKit/WatchKit.h>

@interface NRMAWKApplicationDelegateBase : NSObject
@property(weak, nullable) NSObject* realDelegate;

@end

@interface NRMAWKApplicationDelegateBase (private)
- (instancetype _Nullable) initWithOriginalDelegate:(id<WKApplicationDelegate>_Nonnull)delegate;
@property (nonatomic, retain, readonly) id<WKApplicationDelegate> _Nonnull realDelegate;

@end
