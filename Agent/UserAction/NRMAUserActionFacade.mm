//
//  NRMAUserActionFacade.m
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAUserActionFacade.h"
#import "NRMAAnalytics+cppInterface.h"
#include <Connectivity/Facade.hpp>
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRMAFlags.h"
#import "Constants.h"

@interface NRMAUserActionFacade () {
    std::shared_ptr<NewRelic::AnalyticsController> wrappedAnalyticsController;
    NRMAAnalytics * analyticsController;
}
@end

@implementation NRMAUserActionFacade

- (instancetype)initWithAnalyticsController:(NRMAAnalytics *)analytics {
    self = [super init];
    if (self) {
        wrappedAnalyticsController = std::shared_ptr<NewRelic::AnalyticsController>([analytics analyticsController]);
        analyticsController = analytics;
    }
    return self;
}

- (BOOL)recordUserAction:(NRMAUserAction *)userAction {
    if([NRMAFlags shouldEnableNewEventSystem]){
        [analyticsController recordUserAction:userAction];
    } else {
        try {
#if TARGET_OS_WATCH
            __block auto event = self->wrappedAnalyticsController->addUserActionEvent(userAction.associatedMethod.UTF8String,
                                                           userAction.associatedClass.UTF8String,
                                                           userAction.elementLabel.UTF8String,
                                                           userAction.accessibilityId.UTF8String,
                                                           userAction.interactionCoordinates.UTF8String,
                                                           userAction.actionType.UTF8String,
                                                           userAction.elementFrame.UTF8String,
                                                           [NewRelicInternalUtils deviceOrientation].UTF8String,
                                                           [self->analyticsController checkBackgroundStatus]);
            
            [self->analyticsController checkOfflineStatus:^(BOOL isOffline){
                if(isOffline){
                    event->addAttribute(kNRMA_Attrib_offline.UTF8String, @YES.boolValue);
                }
            }];
                    
            return self->wrappedAnalyticsController->addEvent(event);
#else
            auto event = wrappedAnalyticsController->addUserActionEvent(userAction.associatedMethod.UTF8String,
                                                           userAction.associatedClass.UTF8String,
                                                           userAction.elementLabel.UTF8String,
                                                           userAction.accessibilityId.UTF8String,
                                                           userAction.interactionCoordinates.UTF8String,
                                                           userAction.actionType.UTF8String,
                                                           userAction.elementFrame.UTF8String,
                                                           [NewRelicInternalUtils deviceOrientation].UTF8String,
                                                           [analyticsController checkBackgroundStatus]);
            if([self->analyticsController checkOfflineStatus]){
                event->addAttribute(kNRMA_Attrib_offline.UTF8String, @YES.boolValue);
            }
            return self->wrappedAnalyticsController->addEvent(event);
#endif
        } catch (std::exception &error) {
            NRLOG_AGENT_VERBOSE(@"Failed to add TrackedGesture: %s.", error.what());
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"Failed to add TrackedGesture: unknown error.");
        }
    }
    return false;
}

@end
