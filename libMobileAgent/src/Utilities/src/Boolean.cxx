//
// Created by Bryce Buchanan on 11/2/15.
//

#include "Utilities/Boolean.hpp"
#include <iostream>
#include <istream>
#include <sstream>

namespace NewRelic {
    Boolean::Boolean(bool value): BaseValue(BaseValue::Category::BOOLEAN), _value(value) {}

    bool Boolean::equal(const BaseValue& value) const {
        if (value.getCategory() == BaseValue::Category::BOOLEAN) {
            return this->getValue() == static_cast<const Boolean*>(&value)->getValue();
        }
        return false;
    }

    Boolean::Boolean(std::istream& is) : BaseValue(BaseValue::Category::BOOLEAN) {
        is.ignore(std::numeric_limits<std::streamsize>::max(),_delimiter);
        is >> _value;

    }

    Boolean::Boolean(const Boolean& copy)
            : BaseValue(BaseValue::Category::BOOLEAN), _value(copy.getValue()) {}

    Boolean::~Boolean() {}

    void Boolean::put(std::ostream& os) const {
        os << BaseValue::Category::BOOLEAN << _delimiter << _value;
    }

    const bool Boolean::getValue() const {
        return _value;
    }

    std::ostream& operator<<(std::ostream& os, const Boolean& boolean) {
     boolean.put(os);
        return os;
    }

}

