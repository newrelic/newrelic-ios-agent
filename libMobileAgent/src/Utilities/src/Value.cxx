#include "Utilities/Value.hpp"
#include <iostream>

namespace NewRelic {
    //std::bad_alloc may throw
//    std::shared_ptr<String> Value::createValue(const std::string value) {
//        return std::make_shared<NewRelic::String>(new String(value));
//    }

    std::shared_ptr <String> Value::createValue(const char* value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<String>(String(value));
    }
    std::shared_ptr<Number> Value::createValue(double value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Number>(Number(value));
    }

    std::shared_ptr<Number> Value::createValue(long long value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Number>(Number(value));
    }

    std::shared_ptr<Number> Value::createValue(unsigned long long value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Number>(Number(value));
    }

    std::shared_ptr<Boolean> Value::createValue(bool value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Boolean>(Boolean(value));
    }

    std::shared_ptr<BaseValue> Value::createValue(std::istream &is)  {
        BaseValue::Category category;
        is >> category;
        switch (category) {
            case BaseValue::Category::STRING :
                return std::make_shared<String>(String(is)); //throws runtime_error if is generate an empty value.
            case BaseValue::Category::NUMBER :
                return std::make_shared<Number>(Number(is));
            case BaseValue::Category::BOOLEAN:
                return std::make_shared<Boolean>(Boolean(is));
        }
    }


    std::shared_ptr<Number> Value::createValue(int value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Number>(Number(value));
    }

    std::shared_ptr<Number> Value::createValue(unsigned int value) {
        //std::make_shared can throw std::bad_alloc
        return std::make_shared<Number>(Number((unsigned long long)value));
    }
}
