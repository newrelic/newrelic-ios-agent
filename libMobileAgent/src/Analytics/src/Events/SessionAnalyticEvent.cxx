//  Copyright © 2023 New Relic. All rights reserved.

#include "SessionAnalyticEvent.hpp"

namespace NewRelic {

    const std::string& SessionAnalyticEvent::__category = std::string("Session");

    SessionAnalyticEvent::~SessionAnalyticEvent() { }

    SessionAnalyticEvent::SessionAnalyticEvent(unsigned long long timestamp_epoch_millis,
                                               double session_elapsed_time_sec,
                                               AttributeValidator& validator)
    : MobileEvent(timestamp_epoch_millis,
                    session_elapsed_time_sec,
                    validator) { }

    SessionAnalyticEvent::SessionAnalyticEvent(const SessionAnalyticEvent& event)
    : MobileEvent(event) { }

    const std::string& SessionAnalyticEvent::getCategory() const { return __category; }

    std::shared_ptr<NRJSON::JsonObject> SessionAnalyticEvent::generateJSONObject() const {
        return MobileEvent::generateJSONObject();
    }
}
