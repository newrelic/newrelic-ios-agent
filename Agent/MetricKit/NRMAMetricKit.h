//
//  NRMAMetricKit.h
//  Agent
//
//  Created by Chris Dillard on 8/16/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAMetricKit : NSObject <MXMetricManagerSubscriber>

+ (NRMAMetricKit *)sharedInstance;

- (void) start;

- (BOOL) beginRecordingExtendedLaunchTask:(NSString* _Nonnull)taskIdentifier API_AVAILABLE(ios(16.0));
- (BOOL) endRecordingExtendedLaunchTask:(NSString* _Nonnull)taskIdentifier API_AVAILABLE(ios(16.0));

@end

NS_ASSUME_NONNULL_END
