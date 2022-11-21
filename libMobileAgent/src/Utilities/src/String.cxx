#include <istream>
#include <sstream>
#include "Utilities/String.hpp"
#include "Utilities/Util.hpp"
#include <iostream>
#include <stdexcept>

namespace NewRelic {
    String::String(const char *value) : BaseValue(BaseValue::Category::STRING) {
        _value = Util::Strings::escapeCharacterLiterals(std::string(value));
    }

    String::~String() {
    }

    String::String(const String &copy) : BaseValue(copy) {
        this->_value = std::string(copy._value);
    }

    std::ostream &operator<<(std::ostream &os, const String &dt) {
        dt.put(os);
        return os;
    }

    String::String(std::istream &is) : BaseValue(BaseValue::Category::STRING) {
        is.ignore(std::numeric_limits<std::streamsize>::max(), _delimiter);

        std::stringstream oss;

        is.get(*oss.rdbuf(), _delimiter);

        _value = oss.str();

        if (_value.size() == 0) {
            throw std::runtime_error("malformed data.");
        }
    }

    void String::put(std::ostream &os) const {
        os << BaseValue::Category::STRING << _delimiter << _value;
    }

    bool String::equal(const BaseValue &value) const {
        const String *sValue = dynamic_cast<const String *> (&value);
        return this->_value == sValue->_value;
    }

    const std::string String::getValue() {
        return _value;
    }

    std::string String::replaceAll(std::string str, const std::string &from, const std::string &to) const {
        size_t start_pos = 0;
        while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
            str.replace(start_pos, from.length(), to);
            start_pos += to.length(); // Handles case where 'to' is a substring of 'from'
        }
        return str;
    }

}
