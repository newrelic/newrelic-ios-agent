//  Copyright © 2023 New Relic. All rights reserved.

#include "CustomMobileEvent.hpp"
namespace NewRelic {
    const std::string& CustomMobileEvent::__category = std::string("Custom");

     const std::string& CustomMobileEvent::getCategory() const {
         return __category;
     }

    CustomMobileEvent::CustomMobileEvent(const char *name,
                                             unsigned long long timestamp_epoch_millis,
                                             double session_elapsed_time_sec,
                                             AttributeValidator &attributeValidator)
            : NamedAnalyticEvent(name,
                                 timestamp_epoch_millis,
                                 session_elapsed_time_sec,
                                 attributeValidator) {

    }

    CustomMobileEvent::CustomMobileEvent(const CustomMobileEvent& event) :
            NamedAnalyticEvent(event) {}
    std::shared_ptr<NRJSON::JsonObject> CustomMobileEvent::generateJSONObject() const {
        return NamedAnalyticEvent::generateJSONObject();
    }
}
