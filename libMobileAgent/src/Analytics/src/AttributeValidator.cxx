//  Copyright © 2023 New Relic. All rights reserved.

#include "Analytics/AttributeValidator.hpp"
namespace NewRelic {

    AttributeValidator::AttributeValidator(std::function<bool(const char*)> nameValidator,
                                           std::function<bool(const char*)> valueValidator,
                                           std::function<bool(const char*)> eventTypeValidator)
            : _nameValidator(nameValidator),
              _valueValidator(valueValidator),
              _eventTypeValidator(eventTypeValidator) {}

    const std::function<bool(const char *)>& AttributeValidator::getNameValidator() const{
        return _nameValidator;
    }

    const std::function<bool(const char *)>& AttributeValidator::getValueValidator() const{
        return _valueValidator;
    }

    const std::function<bool(const char*)>& AttributeValidator::getEventTypeValidator() const {
        return _eventTypeValidator;
    }

}
