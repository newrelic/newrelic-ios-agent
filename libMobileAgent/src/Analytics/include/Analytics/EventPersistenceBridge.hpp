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

        // jsonAttributes is the event's full generateJSONObject() output,
        // already serialized to a JSON string (same shape the harvest
        // payload itself uses -- timestamp/timeSinceLoad/eventType plus
        // customer attributes). eventUUID/eventType are also passed
        // separately since eventUUID is intentionally not part of that JSON
        // (it's an internal-only key, never sent to the collector).
        virtual void persistEvent(const std::string& eventUUID,
                                   const std::string& eventType,
                                   const std::string& jsonAttributes) = 0;

        // Called when a batch of events is pulled out for a harvest attempt
        // (about to be sent, outcome not yet known). The persisted copies of
        // these events must not be deleted until a later confirmation that the
        // harvest actually succeeded -- a failed/unattempted harvest must still
        // find them on disk for the next retry or for next-launch recovery.
        virtual void markEventsPendingConfirmation(const std::vector<std::string>& eventUUIDs) = 0;

        // Called when an event is evicted from the live in-memory buffer (buffer full),
        // so its persisted copy doesn't outlive it and get resurrected by a later
        // recovery sweep.
        virtual void discardEvent(const std::string& eventUUID) = 0;
    };
}

#endif //LIBMOBILEAGENT_EVENTPERSISTENCEBRIDGE_HPP
