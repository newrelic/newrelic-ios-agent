//
// Created by Bryce Buchanan on 2/4/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Analytics/EventDeserializer.hpp"
#include "Analytics/EventManager.hpp"
#include "Analytics/AttributeDeserializer.hpp"
#include "Analytics/Constants.hpp"

namespace NewRelic {
    std::shared_ptr<AnalyticEvent> EventDeserializer::deserialize(std::istream& is) {
        std::string eventType;
        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> eventType;
        is.ignore(std::numeric_limits<std::streamsize>::max(),AnalyticEvent::_delimiter);

        if (eventType == MobileEvent::__eventType) {
            return deserializeMobileEvent(is);
        } else if (eventType == UserActionEvent::__eventType) {
            return deserializeUserActionEvent(is);
        } else if (eventType == std::string(__kNRMA_RET_mobileView)) {
            return deserializeViewEvent(__kNRMA_RET_mobileView, is);
        } else if (eventType == std::string(__kNRMA_RET_mobileViewTiming)) {
            return deserializeViewEvent(__kNRMA_RET_mobileViewTiming, is);
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

        // Also check fail() — istream::get(streambuf&, delim) sets failbit
        // (not eofbit) when the next char already is the delimiter and zero
        // chars are extracted. Without this guard the loop spins forever.
        while (!is.eof() && !is.fail()) {
            auto attribute = AttributeDeserializer::deserializeAttributes(is);
            if(attribute == nullptr) continue;
            event->insertAttribute(attribute);
        }
        return event;
    }

    /*
     * Reconstitutes a ViewEvent rather than letting MobileView / MobileViewTiming fall
     * through to deserializeCustomEvent, so an offline-stored view event comes back as the
     * same class a live one is emitted as.
     */
    std::shared_ptr<AnalyticEvent> EventDeserializer::deserializeViewEvent(const char* eventType, std::istream &is) {
        AttributeValidator validator{[](const char*){return true;},[](const char*){return true;},[](const char*){return true;}};

        unsigned long long timestamp_millis;
        double session_elapsed_time_sec;

        readStreamToDelimiter(is,AnalyticEvent::_delimiter) >> timestamp_millis;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        readStreamToDelimiter(is, AnalyticEvent::_delimiter) >> session_elapsed_time_sec;
        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        auto event = EventManager::newViewEvent(eventType,
                                                timestamp_millis,
                                                session_elapsed_time_sec,
                                                validator);

        // See deserializeUserActionEvent for the failbit-vs-eofbit explanation. The
        // unguarded `while (auto attribute = ...)` form used by deserializeCustomEvent
        // spins forever here.
        while (!is.eof() && !is.fail()) {
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

        // See deserializeUserActionEvent for the failbit-vs-eofbit explanation.
        while (!is.eof() && !is.fail()) {
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
