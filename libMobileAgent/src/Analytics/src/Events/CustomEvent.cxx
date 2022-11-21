
#include "CustomEvent.hpp"
namespace NewRelic {
    CustomEvent::CustomEvent(std::shared_ptr<std::string> eventType,
                             unsigned long long timestamp_epoch_millis,
                             double session_elapsed_time_sec,
                             AttributeValidator& attributeValidator) : AnalyticEvent(eventType,
                                                                                     timestamp_epoch_millis,
                                                                                     session_elapsed_time_sec,
                                                                                     attributeValidator) {
    }


    CustomEvent::CustomEvent(const CustomEvent& event) : AnalyticEvent(event) {}

    std::shared_ptr<NRJSON::JsonObject> CustomEvent::generateJSONObject() const {
        return AnalyticEvent::generateJSONObject();
    }
    void CustomEvent::put(std::ostream& os) const {
        os << this->getEventType() << AnalyticEvent::_delimiter;
    }
}
