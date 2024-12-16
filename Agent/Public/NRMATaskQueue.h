
//
//  NRMATaskQueue.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/18/14.
//  Copyright © 2023 New Relic. All rights reserved.
//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright © 2023 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

#import <Foundation/Foundation.h>

@interface NRMATaskQueue : NSObject
@property(atomic,strong) NSMutableArray* queue;
+ (void) start;
+ (void) queue:(id)object;
+ (void) stop;

+ (void) synchronousDequeue;
@end
