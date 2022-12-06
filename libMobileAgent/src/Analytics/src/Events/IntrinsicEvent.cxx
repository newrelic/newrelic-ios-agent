
#include <Analytics/Constants.hpp>
#include <IntrinsicEvent.hpp>
#include <Utilities/libLogger.hpp>

namespace NewRelic {


IntrinsicEvent::IntrinsicEvent(std::shared_ptr<std::string> eventType,
                               std::unique_ptr<const Connectivity::Payload> payload,
                               unsigned long long int timestamp_epoch_millis,
                               double session_elapsed_time_sec,
                               AttributeValidator& attributeValidator) : AnalyticEvent(eventType,
                                                                                       timestamp_epoch_millis,
                                                                                       session_elapsed_time_sec,
                                                                                       attributeValidator) {
    if (payload != nullptr) {
        addIntrinsicAttribute(__kNRMA_Attrib_guid, payload->getId().c_str());
        addIntrinsicAttribute(__kNRMA_Attrib_traceId, payload->getTraceId().c_str());
        if(payload->getParentId().length()){
            addIntrinsicAttribute(__kNRMA_Attrib_parentId, payload->getParentId().c_str());
        }
    }
}

void IntrinsicEvent::addIntrinsicAttribute(const char* key, const char* value) {
    try {
        insertAttribute(Attribute<const char*>::createAttribute(key,
                                                                [](const char*) { return true; },
                                                                value,
                                                                [](const char*) { return true; }));
    } catch (std::exception& e) {
        LLOG_VERBOSE("failed to add intrinsic attribute: {%s, %s}",key, value);
    }
}
    
void IntrinsicEvent::addIntrinsicAttribute(const char* key, int value) {
    try {
        insertAttribute(Attribute<int>::createAttribute(key,
                                                        [](const char*) { return true; },
                                                        value,
                                                        [](int) { return true; }));
    } catch (std::exception& e) {
        LLOG_VERBOSE("failed to add intrinsic attribute: {%s, %d}",key, value);
    }
}
} // namespace NewRelic
