#include "Analytics/Attribute.hpp"
#include <stdexcept>

namespace NewRelic {
    template<> std::shared_ptr<BaseValue> Attribute<const char*>::createValue(const char* value) {
        return Value::createValue(value);
    }



}

