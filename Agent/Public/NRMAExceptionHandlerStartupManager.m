//
//  NRMAExceptionHandlerStartupManager.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/5/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAExceptionHandlerStartupManager.h"
#import "NRMAExceptionHandlerManager.h"
#import "NRMAAnalytics.h"
#import "NRMACrashDataUploader.h"
#import "NRMAFlags.h"
#import "NRMAPreviousSessionUploader.h"

@implementation NRMAExceptionHandlerStartupManager

- (void) fetchLastSessionsAnalytics{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @synchronized (self) {
            self.attributeJson = [NRMAAnalytics getLastSessionsAttributes];

            self.eventJson = [NRMAAnalytics getLastSessionsEvents];

            // The previous session's persisted analytics are read exactly once
            // here (for the old event system this read clears the duplication
            // store). Hand the same data to the uploader so it can be sent to
            // the data endpoint on launch without re-reading and double-consuming.
            if ([NRMAFlags shouldEnableSendLastSessionData]) {
                [[NRMAPreviousSessionUploader sharedInstance] setLastSessionAttributeJSON:self.attributeJson
                                                                               eventJSON:self.eventJson];
            }
        }
    });
}

- (void) startExceptionHandler:(NRMACrashDataUploader*)uploader {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @synchronized (self) {

            NSError* serializationError;
            NSArray* events;
            NSDictionary* attributes;

            @try {
                if (self.eventJson != nil && [self.eventJson length] > 0) {

                    events = [NSJSONSerialization JSONObjectWithData:[self.eventJson dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0
                                                               error:&serializationError];
                }
                if (serializationError != nil) {
                    NRLOG_AGENT_VERBOSE(@"Failed to load last session's events for crash: %@",serializationError.localizedDescription);
                }
            } @catch (NSException* e) {
                NRLOG_AGENT_VERBOSE(@"failed to serialize event json: %@",e.reason);
            }

            @try {
                if (self.attributeJson != nil && [self.attributeJson length] > 0) {

                    attributes = [NSJSONSerialization JSONObjectWithData:[self.attributeJson dataUsingEncoding:NSUTF8StringEncoding]
                                                                 options:0
                                                                   error:&serializationError];
                }
                if (serializationError != nil) {
                    NRLOG_AGENT_VERBOSE(@"Failed to load last session's attribute for crash: %@",serializationError.localizedDescription);
                }
            } @catch (NSException* e) {
                NRLOG_AGENT_VERBOSE(@"failed to serialize event json: %@",e.reason);
            }

            [NRMAExceptionHandlerManager startHandlerWithLastSessionsAttributes:attributes
                                                             andAnalyticsEvents:events
                                                                  uploadManager:uploader];
        }
    });
}
@end
