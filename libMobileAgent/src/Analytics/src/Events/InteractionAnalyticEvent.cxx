//  Copyright © 2023 New Relic. All rights reserved.

#include "InteractionAnalyticEvent.hpp"


namespace NewRelic {
    const std::string& InteractionAnalyticEvent::__category = std::string("Interaction");
     const char* InteractionAnalyticEvent::kInteractionTraceDurationKey = "interactionDuration";

    const std::string& InteractionAnalyticEvent::getCategory() const {
        return __category;
    }

    //throws std::out_of_range, std::length_error
    InteractionAnalyticEvent::InteractionAnalyticEvent(const InteractionAnalyticEvent& event) : NamedAnalyticEvent(event) {}

    //throws std::out_of_range, std::length_error
    InteractionAnalyticEvent::InteractionAnalyticEvent(const char *name,
                                                       unsigned long long timestamp_epoch_millis,
                                                       double session_elapsed_time_sec,
                                                       AttributeValidator &attributeValidator)
    : NamedAnalyticEvent::NamedAnalyticEvent(name,
                                             timestamp_epoch_millis,
                                             session_elapsed_time_sec,
                                             attributeValidator) {}


    std::shared_ptr<NRJSON::JsonObject> InteractionAnalyticEvent::generateJSONObject() const {
        return NamedAnalyticEvent::generateJSONObject();
    }
}
