#include <istream>
#include "Utilities/Number.hpp"
#include <iostream>
#include <iomanip>
namespace NewRelic {
    Number::~Number() {

    }


    Number::Number(const Number& copy) : BaseValue(copy) {
        this->tag = copy.tag;
        switch(this->tag) {
            case Number::Tag::DOUBLE:
                this->dbl = copy.dbl;
                break;
            case Number::Tag::LONG:
                this->ll =  copy.ll;
                break;
            case Number::Tag::U_LONG:
                this->ull = copy.ull;
                break;
        }
    }

    Number::Number(int _value)
            : BaseValue(BaseValue::Category::NUMBER), ll((__int64_t)_value), tag(Tag::LONG){}

    Number::Number(__int64_t _value)
            : BaseValue(BaseValue::Category::NUMBER), ll(_value), tag(Tag::LONG){}

    Number::Number(__uint64_t _value)
            : BaseValue(BaseValue::Category::NUMBER), ull(_value),tag(Tag::U_LONG){}

    Number::Number(double _value)
            : BaseValue(BaseValue::Category::NUMBER), dbl(_value),tag(Tag::DOUBLE) {}

    __uint64_t Number::unsignedLongLongValue() const {

        switch (tag) {
            case (Tag::DOUBLE) :
                return (__uint64_t)dbl;
            case (Tag::LONG) :
                return (__int64_t)ll;
            case (Tag::U_LONG) :
                return ull;
        }
    }

    Number::Tag Number::getTag() const {
        return tag;
    }

    double Number::doubleValue() const {
        switch (tag) {
            case (Tag::DOUBLE) :
                return dbl;
            case (Tag::LONG) :
                return (double)ll;
            case (Tag::U_LONG) :
                return (double)ull;
        }
    }
    __int64_t Number::longLongValue() const {

        switch (tag) {
            case (Tag::DOUBLE) :
                return (__int64_t)dbl;
            case (Tag::LONG) :
                return ll;
            case (Tag::U_LONG):
                return (__int64_t)ull;
        }
    }


    bool Number::equal(const BaseValue& value)const {
        const Number* nValue = dynamic_cast<const Number*>(&value);
        if(this->tag != nValue->tag) return false;
        return this->ull == nValue->ull;
    }
    std::ostream& operator<<(std::ostream& os, const Number::Tag& tag) {
        switch(tag) {
            case Number::Tag::DOUBLE :
                os << (int)0;
                break;
            case Number::Tag::LONG :
                os << (int)1;
                break;
            case Number::Tag::U_LONG :
                os << (int)2;
                break;
        }


        return os;
    }
    std::istream& operator>>(std::istream& is, Number::Tag& tag) {
        int i;
        is>>i;
        switch(i) {
            case 0:
                tag = Number::Tag::DOUBLE;
                break;
            case 1:
                tag = Number::Tag::LONG;
                break;
            case 2:
                tag = Number::Tag::U_LONG;
                break;
            default:
                throw std::runtime_error("failed to deserialze tag for Number.");
        }


        return is;
    }

    Number::Number(std::istream& is) : BaseValue(BaseValue::Category::NUMBER) {

        is.ignore(std::numeric_limits<std::streamsize>::max(), _delimiter);

        is >> this->tag;
        is.ignore(std::numeric_limits<std::streamsize>::max(), _delimiter);
        switch(tag) {
            case Number::Tag::DOUBLE:
                is >> this->dbl;
                break;
            case Number::Tag::LONG:
                is >> this->ll;
                break;
            case Number::Tag::U_LONG:
                is >> this->ull;
                break;
        }
    }

    std::ostream& operator<<(std::ostream& os, const Number& dt) {
        dt.put(os);
        return os;
    }
    void Number::put(std::ostream& os) const {
        os << BaseValue::Category::NUMBER << _delimiter << tag << _delimiter;
        switch(tag) {
            case Number::Tag::DOUBLE :
                os << std::setprecision(15) << doubleValue();
                break;
            case Number::Tag::LONG :
                os << std::setprecision(15) << longLongValue();
                break;
            case Number::Tag::U_LONG :
                os << std::setprecision(15) << unsignedLongLongValue();
                break;
        }
    }
}
