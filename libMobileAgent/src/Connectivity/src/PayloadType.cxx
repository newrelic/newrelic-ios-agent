
#include <Connectivity/PayloadType.hpp>

NewRelic::Connectivity::PayloadType::PayloadType(NewRelic::Connectivity::PayloadType::Enum _e) : _e(_e), _s(NewRelic::Connectivity::PayloadType::toString(_e)) {}

std::string NewRelic::Connectivity::PayloadType::toString(NewRelic::Connectivity::PayloadType::Enum e) {
    switch(e) {
        case mobile:
            return "Mobile";
        case invalid_type:
            return "invalid_type";
    }
    return "invalid_type";
}
