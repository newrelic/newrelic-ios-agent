//  Copyright © 2023 New Relic. All rights reserved.

#include "Analytics/AttributeBase.hpp"
#include <Utilities/Util.hpp>
namespace NewRelic {
    AttributeBase::AttributeBase(std::string key, std::shared_ptr<BaseValue> value): _name(
            Util::Strings::escapeCharacterLiterals(key)), _value(value) {}

    std::string AttributeBase::getName() const {
        return _name;
    }

    void AttributeBase::setPersistent(bool persistence) {
        _isPersistent = persistence;
    }

    bool AttributeBase::getPersistent() const{
        return _isPersistent;
    }

    std::shared_ptr<BaseValue> AttributeBase::getValue() const {
        return std::atomic_load(&_value);
    }
    void AttributeBase::setValue(std::shared_ptr<BaseValue> value) {
        std::atomic_store(&_value, std::move(value));
    }

    bool operator==(const AttributeBase& lhs, const AttributeBase& rhs) {
        auto lv = lhs.getValue();
        auto rv = rhs.getValue();
        return lhs._isPersistent == rhs._isPersistent &&
               lhs._name == rhs._name &&
               ((!lv && !rv) || (lv && rv && *lv == *rv));
    }
}
