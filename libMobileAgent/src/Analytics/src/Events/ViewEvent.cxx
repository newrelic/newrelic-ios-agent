//  Copyright © 2026 New Relic. All rights reserved.

#include "ViewEvent.hpp"

namespace NewRelic {

    ViewEvent::ViewEvent(const char* eventType,
                         unsigned long long timestamp_epoch_millis,
                         double session_elapsed_time_sec,
                         AttributeValidator& attributeValidator)
        : AnalyticEvent(std::make_shared<std::string>(std::string(eventType)),
                        timestamp_epoch_millis,
                        session_elapsed_time_sec,
                        attributeValidator) {}

    // The serialized form is identical to a CustomEvent's -- eventType first, then
    // operator<< writes the timestamp, session duration and attributes.
    void ViewEvent::put(std::ostream& os) const {
        os << this->getEventType() << AnalyticEvent::_delimiter;
    }
}
