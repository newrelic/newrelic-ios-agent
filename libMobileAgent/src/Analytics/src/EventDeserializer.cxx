//
// Created by Bryce Buchanan on 2/4/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Analytics/EventDeserializer.hpp"
#include "Analytics/EventManager.hpp"
#include "Analytics/AttributeDeserializer.hpp"

namespace NewRelic {
    std::shared_ptr<AnalyticEvent> EventDeserializer::deserialize(std::istream& is) {
        std::string eventType;
        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> eventType;
        is.ignore(std::numeric_limits<std::streamsize>::max(),AnalyticEvent::_delimiter);

        if (eventType == MobileEvent::__eventType) {
            return deserializeMobileEvent(is);
        } else if (eventType == UserActionEvent::__eventType) {
            return deserializeUserActionEvent(is);
        } else if (eventType.length()) {
            return deserializeCustomEvent(eventType, is);
        } else {
            throw std::runtime_error("unnamed event type in stream.");
        }
    }

    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeCustomEvent(std::string& eventType, std::istream& is) {
        AttributeValidator validator{[](const char*){return true;},[](const char*){return true;},[](const char*){return true;}};

        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is, AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        auto event = EventManager::newCustomEvent(eventType.c_str(),
                                                  timestamp_millis,
                                                  session_elapsed_time_sec,
                                                  validator);

        while (auto attribute = AttributeDeserializer::deserializeAttributes(is)){
            if(attribute == nullptr) continue;
            event->insertAttribute(attribute);
        }
        return event;
    }

    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeUserActionEvent(std::istream &is) {
        AttributeValidator validator{[](const char*){return true;},[](const char*){return true;},[](const char*){return true;}};

        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is, AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        auto event = EventManager::newUserActionEvent(timestamp_millis,
                                                      session_elapsed_time_sec,
                                                      validator);

        while (!is.eof()) {
            auto attribute = AttributeDeserializer::deserializeAttributes(is);
            if(attribute == nullptr) continue;
            event->insertAttribute(attribute);
        }
        return event;
    }



    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeMobileEvent(std::istream& is) {
        std::shared_ptr<AnalyticEvent> event;
        AttributeValidator validator{[](const char*){return true;},[](const char*){return true;},[](const char*){return true;}};
        std::string category;
        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> category;

        is.ignore(std::numeric_limits<std::streamsize>::max(),AnalyticEvent::_delimiter);

        if (category == InteractionAnalyticEvent::__category) {
            event = deserializeInteractionEvent(is, validator);
        } else if (category == CustomMobileEvent::__category) {
            event = deserializeCustomMobileEvent(is, validator);
        } else if (category == SessionAnalyticEvent::__category) {
            event = deserializeSessionEvent(is,validator);
        } else {
            throw std::runtime_error("unrecognized event type in stream.");
        }

        while (!is.eof()) {
            auto attribute = AttributeDeserializer::deserializeAttributes(is);
            if (attribute == nullptr) continue;
            event->insertAttribute(attribute);
        }
        return event;
    }


    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeCustomMobileEvent(std::istream& is,
                                                                                   AttributeValidator& validator) {
        std::string name;
        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        name = readStreamToDelimiter(is,AnalyticEvent::_delimiter).str();
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is, AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        return EventManager::newCustomMobileEvent(name.c_str(),
                                                  timestamp_millis,
                                                  session_elapsed_time_sec,
                                                  validator);
    }

    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeSessionEvent(std::istream& is,
                                                                                      AttributeValidator& validator) {
        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is, AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        return EventManager::newSessionAnalyticEvent(timestamp_millis,
                                                     session_elapsed_time_sec,
                                                     validator);
    }
    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeInteractionEvent(std::istream& is,
                                                                                                 AttributeValidator& validator) {
        std::string name;
        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        name = readStreamToDelimiter(is,AnalyticEvent::_delimiter).str();
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        return EventManager::newInteractionAnalyticEvent(name.c_str(),
                                                         timestamp_millis,
                                                         session_elapsed_time_sec,
                                                         validator);
    }
}
