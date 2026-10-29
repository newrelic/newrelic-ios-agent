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
#import "NRMAJSON.h"
#import "NRMAFlags.h"

@implementation NRMAExceptionHandlerStartupManager

- (void) fetchLastSessionsAnalytics{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @synchronized (self) {
            // Unused when event persistence is on -- NRMACrashDataWriter sources this instead.
            if ([NRMAFlags shouldEnableEventPersistence]) {
                return;
            }
            self.attributeJson = [NRMAAnalytics getLastSessionsAttributes];
        }
    });
}

- (void) startExceptionHandler:(NRMACrashDataUploader*)uploader {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @synchronized (self) {

            NSError* serializationError;
            NSDictionary* attributes;

            @try {
                if (self.attributeJson != nil && [self.attributeJson length] > 0) {

                    attributes = [NRMAJSON JSONObjectWithData:[self.attributeJson dataUsingEncoding:NSUTF8StringEncoding]
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
                                                                  uploadManager:uploader];
        }
    });
}
@end
