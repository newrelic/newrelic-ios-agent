#include "Analytics/AttributeBase.hpp"
#include <Utilities/Util.hpp>
namespace NewRelic {
    AttributeBase::AttributeBase(std::string key, std::shared_ptr<BaseValue> value): _name(
            Util::Strings::escapeCharacterLiterals(key)), _value(value) {}

    std::string AttributeBase::getName() const {
        return _name;
    }

    std::shared_ptr<BaseValue> AttributeBase::getValue() const {
        return _value;
    }

    void AttributeBase::setPersistent(bool persistence) {
        _isPersistent = persistence;
    }

    bool AttributeBase::getPersistent() const{
        return _isPersistent;
    }

    void AttributeBase::setValue(std::shared_ptr<BaseValue> value) {
        _value = value;
    }

    bool operator==(const AttributeBase& lhs, const AttributeBase& rhs) {
        return lhs._isPersistent == rhs._isPersistent && lhs._name == rhs._name && *lhs._value == *rhs._value;
    }
}
