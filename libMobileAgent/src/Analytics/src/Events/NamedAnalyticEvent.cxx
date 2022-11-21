#include "NamedAnalyticEvent.hpp"
#include <iomanip>
#include <Utilities/Util.hpp>


namespace NewRelic {

    NamedAnalyticEvent::NamedAnalyticEvent(const NamedAnalyticEvent& event)
    : MobileEvent(event) {
        _name = event._name;
    }

    //throws std::out_of_range, std::length_error
    NamedAnalyticEvent::NamedAnalyticEvent(const char *name,
                                           unsigned long long timestamp_epoch_millis,
                                           double session_elapsed_time_sec,
                                           AttributeValidator &attributeValidator)
            :  MobileEvent(timestamp_epoch_millis,
                             session_elapsed_time_sec,
                             attributeValidator) {
        _name = Util::Strings::escapeCharacterLiterals(std::string(name));
    }
    std::shared_ptr<NRJSON::JsonObject> NamedAnalyticEvent::generateJSONObject() const
    {
        auto json =  MobileEvent::generateJSONObject();
        (*json)["name"] = _name;

        return json;
    }

    bool NamedAnalyticEvent::equal(const AnalyticEvent& event) const {
        if (event.getEventType() != this->__eventType) return false;
        if (static_cast<const NamedAnalyticEvent&>(event).getCategory() != this->getCategory()) return false;
        if (static_cast<const NamedAnalyticEvent&>(event)._name != this->_name) return false;
        return MobileEvent::equal(event);
    }

    void NamedAnalyticEvent::put(std::ostream& os) const {
        MobileEvent::put(os);
        os << std::setprecision(15) << _name << _delimiter;
    }



}
