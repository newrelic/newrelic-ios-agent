//
//  NRMAAppInstallMetricGenerator.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/19/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAppInstallMetricGenerator.h"
#import "NRConstants.h"
#import "NRMATaskQueue.h"
#import "NRMAHarvestController.h"
#import "NRMAMetric.h"
#import "NRMAAnalytics.h"
#import "NRMABool.h"
#import "Constants.h"
#import "NRMASupportMetricHelper.h"

@interface NRMAAppInstallMetricGenerator ()
@property(strong) NRMAMetric* installMetric;
@property(assign) BOOL shouldGenerateSecureUDIDReturnNil;
@property(assign) BOOL shouldGenerateInstallAttributes;
// Will auto-nil if released.
@property(weak) NRMAAnalytics* analyticsController;
@end

@implementation NRMAAppInstallMetricGenerator

- (instancetype) init {
    self = [super init];
    if (self) {
        // kNRMADidGenerateNewUDIDNotification will fire very early in the app
        // lifecycle; before the harvester is setup, before the taskqueue is
        // ready to receive measurements. To solve this problem this object will
        // hold onto the generated metric and wait until the harvester signals
        // with -onHarvestBefore. This will require NRMAAppInstallMetricGenerator
        // to be added to the harvestAware list.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didGenerateNewUDID:)
                                                     name:kNRMADidGenerateNewUDIDNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didInitializeAnalytics:)
                                                     name:kNRMAAnalyticsInitializedNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(secureUDIDReturnedNil:)
                                                     name:kNRMASecureUDIDIsNilNotification
                                                   object:nil];

        self.shouldGenerateInstallAttributes = NO;
        self.shouldGenerateSecureUDIDReturnNil = NO;
    }
    return self;
}

- (void) removeUDIDObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNRMADidGenerateNewUDIDNotification
                                                  object:nil];
}


- (void) removeAnalyticsObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNRMAAnalyticsInitializedNotification
                                                  object:nil];
}


- (void) removeSecureUDIDObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNRMASecureUDIDIsNilNotification
                                                  object:nil];
}

- (void) dealloc {

    [self removeUDIDObserver];
    [self removeAnalyticsObserver];
    [self removeSecureUDIDObserver];

    self.analyticsController = nil;
}

- (void) sendNoSecureUDIDAttribute:(NRMAAnalytics*)analytics {
    [analytics setNRSessionAttribute:kNRMANoSecureUDIDAttribute 
                               value:[[NRMABool alloc] initWithBOOL:YES]];
}
- (void) secureUDIDReturnedNil:(NSNotification*)notif {
    @synchronized(self) {
        [self removeSecureUDIDObserver];
        if (self.analyticsController) {
            [self sendNoSecureUDIDAttribute:self.analyticsController];
        } else {
            self.shouldGenerateSecureUDIDReturnNil = YES;
        }
    }
}

- (void) didGenerateNewUDID:(NSNotification*)notif {
    // Notification contains UDID in user dictionary.
    // Synchronized to ensure these operations are atomic in regards to the analyticsController notification.
    @synchronized(self) {
        // This notification should only fire 0 or 1 time per app lifecycle.
        [self removeUDIDObserver];

        // At the point in time this notification is fired, the measurements engine
        // (and the harvester, for that matter) is not yet initialized. The metric will be stored,
        // and it will be deferred to NewRelicAgentInternal.m to queue this object
        // as a harvest listener. Once the harvest listener is fired this metric will be queue
        // from -onHarvestBefore.
        self.installMetric = [[NRMAMetric alloc] initWithName:kNRMAAppInstallMetric
                                                        value:@1
                                                        scope:nil];

        [NRMASupportMetricHelper enqueueInstallMetric];

        if (self.analyticsController) {
            // This code path is unlikely to ever occur. The analytics engine will
            // most likely never be initialized at the time of this execution.
            [self sendInstallAttributeToAnalytics:self.analyticsController];

            // Once the session attribute is recorded the analytics controller is
            // no longer needed for this application lifecycle.
            self.analyticsController = nil;
        } else {
            // If kNRMADidGenerateNewUDIDNotification is fired this code path will most likely
            // be executed. There should be no situation that kNRMAAnalyticsInitializedNotification
            // is observed before this notification.
            // To effectively record a session attribute identifying a new install occurred,
            // we must wait for the analytics controller to be initialized. This flag will indicate
            // we received the kNRMAAnalyticsInitializedNotification notification when the analytics
            // controller is available to receive input.
            self.shouldGenerateInstallAttributes = YES;
        }
    }
}

- (void) sendInstallAttributeToAnalytics:(NRMAAnalytics*)analytics {
    [analytics setNRSessionAttribute:kNRMA_RA_install
                               value:[[NRMABool alloc] initWithBOOL:YES]];
}
- (void) didInitializeAnalytics:(NSNotification*)notif {

    // Synchronized to ensure these operations are atomic in regards to the didGenerateNewUDID notification.
    @synchronized(self) {
        [self removeAnalyticsObserver];
        
        // A reference to the AnalyticsController is provided by the notification.
        NRMAAnalytics* analytics = notif.userInfo[kNRMAAnalyticsControllerKey];

        if (self.shouldGenerateSecureUDIDReturnNil) {
            [self sendNoSecureUDIDAttribute:analytics];
        }

        if (self.shouldGenerateInstallAttributes) {
            // If kNRMAAnalyticsInitializedNotification was already captured,
            // immediately generate the new attribute using the analytics controller ref.
            [self sendInstallAttributeToAnalytics:analytics];
        }
        // kNRMAAnalyticsInitializedNotification hasn't been captured yet.
        // Hold onto the ref to the analyticsController in a weak property in case we see the notification later
        // if kNRMAAnalyticsInitializedNotification will be generated for this app install this code path will not
        // execute. However, this path will execute for most app sessions when there is already a valid UDID.
        // There should be no issue with holding onto this weak reference, as the property will be niled out when the ref is deallocated.
        self.analyticsController = analytics;
    }
}

@end
