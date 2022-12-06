#include "Analytics/EventBufferConfig.hpp"

namespace NewRelic {

EventBufferConfig* EventBufferConfig::__instance = nullptr;

EventBufferConfig& EventBufferConfig::getInstance() {
    if (EventBufferConfig::__instance == nullptr) {
        EventBufferConfig::__instance = new EventBufferConfig();
    }
    return *EventBufferConfig::__instance;
}

void EventBufferConfig::setMaxEventBufferTime(unsigned int maxBufferTime) {
    _max_buffer_time_sec = maxBufferTime;
}

void EventBufferConfig::setMaxEventBufferSize(unsigned int maxBufferSize) {
    _max_buffer_size = maxBufferSize;
}

unsigned int EventBufferConfig::get_max_buffer_time_sec() const {
    return _max_buffer_time_sec;
}

unsigned int EventBufferConfig::get_max_buffer_size() const {
    return _max_buffer_size;
}
}
