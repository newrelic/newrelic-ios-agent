//  Copyright © 2023 New Relic. All rights reserved.

#include <sstream>
#include <array>
#include <iostream>
#include "Analytics/EventManager.hpp"
#include <algorithm>
#include "NetworkErrorEvent.hpp"
#include "RequestEvent.hpp"
#include "Utilities/Util.hpp"
#include "Analytics/EventDeserializer.hpp"
#include "Analytics/EventBufferConfig.hpp"

namespace NewRelic {

EventManager::EventManager(PersistentStore<std::string, AnalyticEvent>& store) :
        _eventDuplicationStore(store) {
}

EventManager::~EventManager() {

}


bool EventManager::didReachMaxQueueTime(unsigned long long currentTimestamp_ms) {
    if (_oldest_event_timestamp_ms == 0) return false; //default value of _oldest_event_timestamp_ms
    unsigned long long oldest_event_age_ms = currentTimestamp_ms - _oldest_event_timestamp_ms;
    return oldest_event_age_ms / 1000 >= EventBufferConfig::getInstance().get_max_buffer_time_sec();
}

void EventManager::setMaxBufferSize(unsigned int size) {
    EventBufferConfig::getInstance().setMaxEventBufferSize(size);
}

void EventManager::empty() {

    std::unique_lock<std::recursive_mutex> lock1(this->_eventsMutex, std::defer_lock);
    lock1.lock();
    _events.clear();
    _eventDuplicationStore.clear();
    _oldest_event_timestamp_ms = 0;
    //we're empty so let's reset the total number of attempted inserts.
    _total_attempted_inserts = 0;
}

    std::string EventManager::createKey(std::shared_ptr<AnalyticEvent> event) {
        std::stringstream ss;
        ss << *event;
        std::string s{ss.str()};

        for(auto it = std::remove_if(s.begin(),s.end(),&isspace); it != s.end() ; s.erase(it));
        return s;
    }

bool EventManager::addEvent(std::shared_ptr<AnalyticEvent> event) {
    std::unique_lock<std::recursive_mutex> lock1(this->_eventsMutex, std::defer_lock);
    lock1.lock();
    if (event == nullptr) {
        return false;
    }
    if (_events.size() >= EventBufferConfig::getInstance().get_max_buffer_size()) {
        //throw away something...
        int index = getRemovalIndex();
        //concern if the total number of inserts exceeds RAND_MAX (guaranteed to be at least ~32,000, but could be 2,147,483,647) this will become crappy, index will always = 1;
        //todo: this would be a good spot for agent health / recover
        if (index < _events.size()) {
            //iterator the event to remove
            auto eventIterator = _events.begin() + index;
            //remove it from the duplication store
            std::stringstream deleteKey;
            deleteKey << *eventIterator;
            _eventDuplicationStore.remove(deleteKey.str());
            //remove it from the vector
            _events.erase(eventIterator);
            //add new event to the vector
            _events.push_back(event);
            //insert ne event into the duplication store

                _eventDuplicationStore.store(EventManager::createKey(event),event);
        };
    } else {
        //buffer size limit not reach
        //simply add new event to vector
        _events.push_back(event);
        //and to duplication store.

            _eventDuplicationStore.store(EventManager::createKey(event),event);
        if (_events.size() == 1) {
            //wait until the event is actually pushed before we assume it's the oldest event.
            _oldest_event_timestamp_ms = event->_timestamp_epoch_millis;
        }
    }
    //increment the total attempted inserts.
    _total_attempted_inserts++;
    return true;
}

int EventManager::getRemovalIndex() {
    if (_total_attempted_inserts > 0) {
        return rand() % _total_attempted_inserts;
    } else {
        return 0;
    }
}

void EventManager::setMaxBufferTime(unsigned int seconds) {
    EventBufferConfig::getInstance().setMaxEventBufferTime(seconds);
}

std::shared_ptr<AnalyticEvent> EventManager::newEvent(std::istream& is) {
    return EventDeserializer::deserialize(is);
}

std::shared_ptr<InteractionAnalyticEvent> EventManager::newInteractionAnalyticEvent(const char* name,
                                                                                    unsigned long long timestamp_epoch_millis,
                                                                                    double session_elapsed_time_sec,
                                                                                    AttributeValidator& attributeValidator) {

    //throws std::out_of_range, std::length_error
    auto event = std::make_shared<InteractionAnalyticEvent>(InteractionAnalyticEvent(name,
                                                                                     timestamp_epoch_millis,
                                                                                     session_elapsed_time_sec,
                                                                                     attributeValidator));
    return event;
}


std::shared_ptr<NetworkErrorEvent> EventManager::newNetworkErrorEvent(unsigned long long timestamp_epoch_millis,
                                                                      double session_elapsed_time_sec,
                                                                      const char* encodedResponseBody,
                                                                      const char* appDataHeader,
                                                                      std::unique_ptr<const Connectivity::Payload> payload,
                                                                      AttributeValidator& attributeValidator) {

    auto event = std::make_shared<NetworkErrorEvent>(
            NetworkErrorEvent(timestamp_epoch_millis,
                              session_elapsed_time_sec,
                              encodedResponseBody,
                              appDataHeader,
                              std::move(payload),
                              attributeValidator));
    return event;
}

std::shared_ptr<RequestEvent> EventManager::newRequestEvent(unsigned long long timestamp_epoch_millis,
                                                            double session_elapsed_time_sec,
                                                            std::unique_ptr<const Connectivity::Payload> payload,
                                                            AttributeValidator& attributeValidator) {
    auto event = std::make_shared<RequestEvent>(
            RequestEvent(timestamp_epoch_millis, session_elapsed_time_sec, std::move(payload), attributeValidator));
    return event;
}

std::shared_ptr<SessionAnalyticEvent> EventManager::newSessionAnalyticEvent(unsigned long long timestamp_epoch_millis,
                                                                            double session_elapsed_time_sec,
                                                                            AttributeValidator& attributeValidator) {
    auto event = std::make_shared<SessionAnalyticEvent>(SessionAnalyticEvent(timestamp_epoch_millis,
                                                                             session_elapsed_time_sec,
                                                                             attributeValidator));
    return event;
}


std::shared_ptr<UserActionEvent> EventManager::newUserActionEvent(unsigned long long timestamp_epoch_millis,
                                                                  double session_elapsed_time_sec,
                                                                  AttributeValidator &attributeValidator) {
    auto event = std::make_shared<UserActionEvent>(
            UserActionEvent(timestamp_epoch_millis,
                                session_elapsed_time_sec,
                                attributeValidator));
    return event;
}

std::shared_ptr<CustomMobileEvent> EventManager::newCustomMobileEvent(const char* name,
                                                                      unsigned long long timestamp_epoch_millis,
                                                                      double session_elapsed_time_sec,
                                                                      AttributeValidator& attributeValidator) {

    auto event = std::make_shared<CustomMobileEvent>(
            CustomMobileEvent(name,
                              timestamp_epoch_millis,
                              session_elapsed_time_sec,
                              attributeValidator));
    return event;
}

std::shared_ptr<BreadcrumbEvent> EventManager::newBreadcrumbEvent(unsigned long long timestamp_epoch_millis,
                                                                  double session_elapsed_time_sec,
                                                                  AttributeValidator& attributeValidator) {
    auto event = std::make_shared<BreadcrumbEvent>(BreadcrumbEvent(timestamp_epoch_millis,
                                                                   session_elapsed_time_sec,
                                                                   attributeValidator));
    return event;
}

std::shared_ptr<CustomEvent> EventManager::newCustomEvent(const char* eventType,
                                                          unsigned long long timestamp_epoch_millis,
                                                          double session_elapsed_time_sec,
                                                          AttributeValidator& attributeValidator) {

    auto event = std::make_shared<CustomEvent>(
            CustomEvent(std::make_shared<std::string>(Util::Strings::escapeCharacterLiterals(std::string(eventType))),
                        timestamp_epoch_millis,
                        session_elapsed_time_sec,
                        attributeValidator));
    return event;
}


std::shared_ptr<NRJSON::JsonArray> EventManager::toJSON() const {
    std::unique_lock<std::recursive_mutex> lock1(this->_eventsMutex, std::defer_lock);
    lock1.lock();
    return EventManager::toJSON(_events);
}

std::shared_ptr<NRJSON::JsonArray> EventManager::toJSON(std::vector<std::shared_ptr<AnalyticEvent>> events) {
    NRJSON::JsonArray array = NRJSON::JsonArray();
    for (auto iterator = events.cbegin(); iterator != events.cend(); iterator++) {
        array.push_back(*(iterator->get()->generateJSONObject()));
    }
    auto json = std::make_shared<NRJSON::JsonArray>(array);
    return json;
}
}
