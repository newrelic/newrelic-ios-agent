//
//  NRMAEventPersistenceBridge.hpp
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#ifndef NRMAEventPersistenceBridge_hpp
#define NRMAEventPersistenceBridge_hpp

#include <Analytics/EventPersistenceBridge.hpp>

namespace NewRelic {
    // Legacy (C++) event-system implementation of EventPersistenceBridge --
    // forwards into NREventPersistenceController, since the Analytics library
    // has no notion of sessionId/realAgentId itself.
    class NRMAEventPersistenceBridge : public EventPersistenceBridge {
        virtual void persistEvent(const std::string& eventUUID,
                                   const std::string& eventType,
                                   const std::string& jsonAttributes) override;

        virtual void markEventsPendingConfirmation(const std::vector<std::string>& eventUUIDs) override;

        virtual void discardEvent(const std::string& eventUUID) override;
    };
}

#endif /* NRMAEventPersistenceBridge_hpp */
