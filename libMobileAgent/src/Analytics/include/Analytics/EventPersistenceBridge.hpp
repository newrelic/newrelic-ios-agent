//  Copyright © 2026 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_EVENTPERSISTENCEBRIDGE_HPP
#define LIBMOBILEAGENT_EVENTPERSISTENCEBRIDGE_HPP

#include <string>
#include <vector>

namespace NewRelic {
    // Lets EventManager hand freshly-recorded events to the platform's event
    // persistence layer (disk storage for crash/force-quit recovery) without
    // the Analytics library knowing anything about Foundation/ObjC -- mirrors
    // the LoggerBridge/LibLogger pattern used for logging.
    class EventPersistenceBridge {
    public:
        virtual ~EventPersistenceBridge() = default;

        // jsonAttributes is the event's full generateJSONObject() output. eventUUID is
        // passed separately since it's internal-only, never part of that JSON.
        virtual void persistEvent(const std::string& eventUUID,
                                   const std::string& eventType,
                                   const std::string& jsonAttributes) = 0;

        // Called when events are pulled out for a harvest attempt whose outcome isn't
        // known yet -- don't delete until a later confirmation that it succeeded.
        virtual void markEventsPendingConfirmation(const std::vector<std::string>& eventUUIDs) = 0;

        // Called when an event is evicted from the live buffer, so it isn't
        // resurrected by a later recovery sweep.
        virtual void discardEvent(const std::string& eventUUID) = 0;
    };
}

#endif //LIBMOBILEAGENT_EVENTPERSISTENCEBRIDGE_HPP
