//  Copyright © 2026 New Relic. All rights reserved.

#include <Analytics/Constants.hpp>
#include "ViewEvent.hpp"

namespace NewRelic {

    ViewEvent::ViewEvent(const char* eventType,
                         const char* category,
                         unsigned long long timestamp_epoch_millis,
                         double session_elapsed_time_sec,
                         AttributeValidator& attributeValidator)
        : AnalyticEvent(std::make_shared<std::string>(std::string(eventType)),
                        timestamp_epoch_millis,
                        session_elapsed_time_sec,
                        attributeValidator),
          _category(category == nullptr ? std::string(__kNRMA_RET_mobile) : std::string(category)) {}

    const std::string& ViewEvent::getCategory() const {
        return _category;
    }

    std::shared_ptr<NRJSON::JsonObject> ViewEvent::generateJSONObject() const {
        auto json = AnalyticEvent::generateJSONObject();

        (*json)[__kNRMA_RA_category] = getCategory().c_str();

        return json;
    }

    // The serialized form is identical to a CustomEvent's -- eventType first, then
    // operator<< writes the timestamp, session duration and attributes. The category is
    // deliberately NOT serialized: it is a constant per event type, so the deserializer
    // reconstitutes it from the event type it already read.
    void ViewEvent::put(std::ostream& os) const {
        os << this->getEventType() << AnalyticEvent::_delimiter;
    }
}
