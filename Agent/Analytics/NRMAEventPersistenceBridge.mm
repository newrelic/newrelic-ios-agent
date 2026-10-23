//
//  NRMAEventPersistenceBridge.mm
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "NRMAEventPersistenceBridge.hpp"
#include <sstream>
#include <iomanip>
#import "NewRelicAgentInternal.h"
#import "NRMAAnalytics+cppInterface.h"
#import "NRMAExceptionMetaDataStore.h"
#import "NRMAJSON.h"
#import "Constants.h"
#import "NRLogger.h"
#import <NewRelic/NewRelic-Swift.h>

namespace NewRelic {

    void NRMAEventPersistenceBridge::persistEvent(const std::string& eventUUID,
                                                   const std::string& eventType,
                                                   const std::string& jsonAttributes) {
        @try {
            NSString *jsonString = [NSString stringWithUTF8String:jsonAttributes.c_str()];
            if (jsonString == nil) {
                return;
            }

            NSError *error = nil;
            NSDictionary *attributes = [NRMAJSON JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:&error];
            if (error != nil || ![attributes isKindOfClass:[NSDictionary class]]) {
                NRLOG_AGENT_VERBOSE(@"NREventPersistence: failed to parse event JSON for persistence: %@", error.localizedDescription);
                return;
            }

            NSNumber *timestampNumber = attributes[kNRMA_RA_timestamp];
            int64_t timestampMs = [timestampNumber isKindOfClass:[NSNumber class]] ? timestampNumber.longLongValue : 0;

            NewRelicAgentInternal *agent = [NewRelicAgentInternal sharedInstance];
            NSString *sessionId = [agent currentSessionId] ?: @"";

            // The legacy system has no public/private attribute split like
            // NRMASAM -- getSessionAttributeJSON() returns everything that's
            // been set (reserved NR-prefixed keys included), used here as the
            // closest available "mutableAttributesSnapshot".
            NSDictionary *mutableSnapshot = @{};
            NRMAAnalytics *analytics = agent.analyticsController;
            if (analytics != nil) {
                try {
                    std::shared_ptr<NewRelic::AnalyticsController> cppController = [analytics analyticsController];
                    if (cppController) {
                        auto attributeJson = cppController->getSessionAttributeJSON();
                        if (attributeJson) {
                            std::stringstream ss;
                            ss << std::setprecision(15) << *attributeJson;
                            NSString *snapshotJsonString = [NSString stringWithUTF8String:ss.str().c_str()];
                            NSDictionary *parsedSnapshot = [NRMAJSON JSONObjectWithData:[snapshotJsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                                                  options:0
                                                                                    error:nil];
                            if ([parsedSnapshot isKindOfClass:[NSDictionary class]]) {
                                mutableSnapshot = parsedSnapshot;
                            }
                        }
                    }
                } catch (std::exception& e) {
                    NRLOG_AGENT_VERBOSE(@"NREventPersistence: failed to read session attributes: %s", e.what());
                } catch (...) {
                    NRLOG_AGENT_VERBOSE(@"NREventPersistence: failed to read session attributes.");
                }
            }

            NSString *eventUUIDString = [NSString stringWithUTF8String:eventUUID.c_str()];
            NSString *eventTypeString = [NSString stringWithUTF8String:eventType.c_str()];

            [[NREventPersistenceController shared] recordEventWithEventUUID:eventUUIDString
                                                                    eventType:eventTypeString
                                                                  timestampMs:timestampMs
                                                                   attributes:attributes
                                                                    sessionId:sessionId
                                                                  realAgentId:NRMA_getAgentId()
                                                    mutableAttributesSnapshot:mutableSnapshot];
        } @catch (NSException *exception) {
            NRLOG_AGENT_ERROR(@"NREventPersistence: failed to persist legacy-path event: %@", exception.reason);
        }
    }

    void NRMAEventPersistenceBridge::markEventsPendingConfirmation(const std::vector<std::string>& eventUUIDs) {
        if (eventUUIDs.empty()) {
            return;
        }
        @try {
            NSMutableArray<NSString *> *uuids = [NSMutableArray arrayWithCapacity:eventUUIDs.size()];
            for (const auto& uuid : eventUUIDs) {
                [uuids addObject:[NSString stringWithUTF8String:uuid.c_str()]];
            }
            [[NREventPersistenceController shared] markEventsPendingConfirmationWithEventUUIDs:uuids];
        } @catch (NSException *exception) {
            NRLOG_AGENT_ERROR(@"NREventPersistence: failed to mark legacy-path events pending confirmation: %@", exception.reason);
        }
    }

    void NRMAEventPersistenceBridge::discardEvent(const std::string& eventUUID) {
        @try {
            [[NREventPersistenceController shared] discardPersistedEventWithEventUUID:[NSString stringWithUTF8String:eventUUID.c_str()]];
        } @catch (NSException *exception) {
            NRLOG_AGENT_ERROR(@"NREventPersistence: failed to discard evicted legacy-path event: %@", exception.reason);
        }
    }
}
