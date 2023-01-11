//  Copyright © 2023 New Relic. All rights reserved.

#include <Utilities/Number.hpp>
#include <Utilities/String.hpp>
#include "Utilities/BaseValue.hpp"
#include <iostream>

//WARNING: do not change these values.
//         previous agent versions depend on
//         the consistency of these values.
const short __kPersistentStoreStringId  = 0;
const short __kPersistentStoreNumberId  = 1;
const short __kPersistentStoreBooleanId = 2;

namespace NewRelic {
    BaseValue::BaseValue(BaseValue::Category category)
    : _category(category) {  }



    BaseValue::BaseValue(const BaseValue& copy) {
        this->_category = copy._category;
    }
    BaseValue::Category BaseValue::getCategory() const {
        return _category;
    }
    BaseValue::~BaseValue() {

    }


    bool operator==(const BaseValue& lhs, const BaseValue& rhs) {
        return typeid(lhs) == typeid(rhs) && lhs.equal(rhs);
    }


    std::istream& operator>> (std::istream& os, BaseValue::Category& dt) {
        short i;
        os >> i;

        switch(i) {
            case __kPersistentStoreNumberId:
                dt = BaseValue::Category::NUMBER;
                break;
            case __kPersistentStoreStringId:
                dt = BaseValue::Category::STRING;
                break;
            case __kPersistentStoreBooleanId:
                dt = BaseValue::Category::BOOLEAN;
                break;
            default:
                throw std::runtime_error("Failed to deserialize: invalid Category value");
        }

        return os;
    }
    std::ostream& operator<< (std::ostream& os, const BaseValue::Category& dt) {
        switch(dt) {
            case BaseValue::Category::NUMBER:
                os << __kPersistentStoreNumberId;
                break;
            case BaseValue::Category::STRING:
                os << __kPersistentStoreStringId;
                break;
            case BaseValue::Category::BOOLEAN:
                os << __kPersistentStoreBooleanId;
        }

        return os;
    }

    std::ostream& operator<<(std::ostream& os, const BaseValue& dt) {
    dt.put(os);
    return os;
    }
}
