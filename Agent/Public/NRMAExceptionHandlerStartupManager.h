//
//  NRMAExceptionHandlerStartupManager.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/5/17.
//  Copyright © 2017 New Relic. All rights reserved.
//
//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright (c) 2022 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

#import <Foundation/Foundation.h>

@class NRMACrashDataUploader;

@interface NRMAExceptionHandlerStartupManager : NSObject

@property(strong) NSString* eventJson;
@property(strong) NSString* attributeJson;

- (void) fetchLastSessionsAnalytics;

- (void) startExceptionHandler:(NRMACrashDataUploader*)uploader;
@end
