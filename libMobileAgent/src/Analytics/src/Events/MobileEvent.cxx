//
// Created by Bryce Buchanan on 2/3/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "MobileEvent.hpp"
namespace NewRelic {
    const std::string MobileEvent::__eventType = std::string("Mobile");
    MobileEvent::MobileEvent(unsigned long long timestamp_epoch_millis, double session_elapsed_time_sec,
                             AttributeValidator& attributeValidator): AnalyticEvent(std::make_shared<std::string>(__eventType),
                                                                                    timestamp_epoch_millis,
                                                                                    session_elapsed_time_sec,
                                                                                    attributeValidator) { }
    void MobileEvent::put(std::ostream& os) const {
        os << MobileEvent::__eventType << AnalyticEvent::_delimiter << this->getCategory() << AnalyticEvent::_delimiter;
    }
    bool MobileEvent::equal(const AnalyticEvent& event) const {
        if(this->getEventType() != event.getEventType()) return false;
        if (this->getCategory() != static_cast<const MobileEvent&>(event).getCategory()) return false;

        return AnalyticEvent::equal(event);
    }
    std::shared_ptr<NRJSON::JsonObject> MobileEvent::generateJSONObject()const {
        auto json = AnalyticEvent::generateJSONObject();

        (*json)["category"] = getCategory().c_str();

        return json;
    }
}
