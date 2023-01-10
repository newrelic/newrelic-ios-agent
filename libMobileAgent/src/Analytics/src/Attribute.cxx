//  Copyright © 2023 New Relic. All rights reserved.

#include "Analytics/Attribute.hpp"
#include <stdexcept>

namespace NewRelic {
    template<> std::shared_ptr<BaseValue> Attribute<const char*>::createValue(const char* value) {
        return Value::createValue(value);
    }



}

