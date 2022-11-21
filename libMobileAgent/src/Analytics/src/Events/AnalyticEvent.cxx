#include "AnalyticEvent.hpp"
#include <chrono>
#include "Analytics/Attribute.hpp"
#include <iomanip>
#include <Utilities/Number.hpp>
#include <Utilities/String.hpp>
#include <Utilities/Boolean.hpp>

namespace NewRelic {

    AnalyticEvent::AnalyticEvent(const std::shared_ptr<std::string> eventType,
                                 unsigned long long timestamp_epoch_millis,
                                 double session_elapsed_time_sec,
                                 AttributeValidator& attributeValidator)
            : _eventType(eventType),
              _timestamp_epoch_millis(timestamp_epoch_millis),
              _session_elapsed_time_sec(session_elapsed_time_sec),
              _attributeValidator(attributeValidator) {
    }


    AnalyticEvent& AnalyticEvent::operator=(const AnalyticEvent& event) {
        _timestamp_epoch_millis = event._timestamp_epoch_millis;
        _session_elapsed_time_sec = event._session_elapsed_time_sec;
        _attributes = event._attributes;
        _attributeValidator = event._attributeValidator;

        return *this;
    }

        bool AnalyticEvent::equal(const AnalyticEvent &event) const {
            if(this->getEventType() != event.getEventType()) return false;
            if(this->_session_elapsed_time_sec != event._session_elapsed_time_sec) return false;
            if(this->_timestamp_epoch_millis != event._timestamp_epoch_millis) return false;
            if(this->_attributes.size() != event._attributes.size()) return false;

            for(auto it = _attributes.cbegin() ; it != _attributes.cend() ; it++) {
                const std::string key = it->first;
                if(!(*(it->second) == *(event._attributes.find(key)->second))) return false;
            }

            return true;
        }

        bool operator==(const AnalyticEvent& lhs, const AnalyticEvent& rhs) {
            return lhs.equal(rhs);
        }
    AnalyticEvent::AnalyticEvent(const AnalyticEvent& event):
            _eventType(event._eventType),
            _timestamp_epoch_millis(event._timestamp_epoch_millis),
            _session_elapsed_time_sec(event._session_elapsed_time_sec),
            _attributeValidator (event._attributeValidator),
            _attributes(event._attributes)
    {}

    const std::string& AnalyticEvent::getEventType() const {
        return *_eventType;
    }

    AnalyticEvent::~AnalyticEvent() {};


    unsigned long long AnalyticEvent::getAgeInMillis() {
        return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock().now().time_since_epoch()).count() - _timestamp_epoch_millis;
    }

    bool AnalyticEvent::insertAttribute(std::shared_ptr<AttributeBase> attribute) {
        auto mappedObj = (_attributes[attribute->getName()] = attribute);
        // map operator[] returns the object inserted, or the object that prevented the insertion
        // we can validate with this information.
        if (&(*mappedObj) != &(*attribute)) {
            const std::string error = std::string(std::string("Inserted duplicate attribute: { \"") + attribute->getName() + std::string("\" } into event."));
            throw std::invalid_argument(error);
        }

        return true;
    }

    bool AnalyticEvent::addAttribute(const char *name, const char *value) {

        auto attrib = Attribute<const char*>::createAttribute(name, _attributeValidator.getNameValidator(),
                                                              value, _attributeValidator.getValueValidator());

        if (attrib == nullptr) {
            return false;
        }

        return insertAttribute(attrib);
    }



    //throws std::out_of_range, std::length_error
    bool AnalyticEvent::addAttribute(const char *name, double value) {
        //throws std::out_of_range, std::length_error
        auto attrib = Attribute<double>::createAttribute(name,
                                                        _attributeValidator.getNameValidator(),
                                                        value,
                                                        [](double) { return true;});

        if (attrib == nullptr) {
            return false;
        }

        return insertAttribute(attrib);
    }

    bool AnalyticEvent::addAttribute(const char* name, bool value) {
        auto attrib = Attribute<bool>::createAttribute(name,
                                                       _attributeValidator.getNameValidator(),
                                                       value,
                                                       [](bool) {return true;});
        if (attrib == nullptr) {
            return false;
        }

        return insertAttribute(attrib);
    }

    bool AnalyticEvent::addAttribute(const char* name,
                                     long long int value) {
        auto attrib = Attribute<long long int>::createAttribute(name,
                                                       _attributeValidator.getNameValidator(),
                                                       value,
                                                       [](long long int) {return true;});
        if (attrib == nullptr) {
            return false;
        }

        return insertAttribute(attrib);
    }

    bool AnalyticEvent::addAttribute(const char* name,
                                     int value) {
        return addAttribute(name, (long long int)value);
    }

    bool AnalyticEvent::addAttribute(const char* name,
                                     unsigned int value) {
        return addAttribute(name, (unsigned long long int)value);
    }

    bool AnalyticEvent::addAttribute(const char* name,
                                     unsigned long long int value) {
        auto attrib = Attribute<unsigned long long int>::createAttribute(name,
                                                       _attributeValidator.getNameValidator(),
                                                       value,
                                                       [](unsigned long long int) {return true;});
        if (attrib == nullptr) {
            return false;
        }

        return insertAttribute(attrib);
    }

    std::ostream& operator<<(std::ostream& os, const AnalyticEvent& event){
        event.put(os);

        os << std::setprecision(15) << event._timestamp_epoch_millis << AnalyticEvent::_delimiter;
        os << std::setprecision(15) << event._session_elapsed_time_sec << AnalyticEvent::_delimiter;
        for(auto it = event._attributes.cbegin() ; it != event._attributes.cend() ; it ++ ) {
            os << it->first << AnalyticEvent::_delimiter;
            const AttributeBase& attribute = *it->second;

            const BaseValue& value = *(attribute.getValue());
            os << std::setprecision(15) << value << AnalyticEvent::_delimiter;
        }

        return os;
    }



    std::shared_ptr<NRJSON::JsonObject> AnalyticEvent::generateJSONObject()const{
        NRJSON::JsonObject object = NRJSON::JsonObject();
        object["eventType"] = getEventType().c_str();
        object["timestamp"] = (double)_timestamp_epoch_millis;
        object["timeSinceLoad"] = _session_elapsed_time_sec;

        for (auto iterator = _attributes.begin() ; iterator != _attributes.end();iterator++) {
            auto value = iterator->second->getValue();
            switch(value->getCategory()) {
                case BaseValue::Category::STRING:
                    object[((std::string)iterator->first).c_str()] = (static_cast<String*>(value.get()))->getValue().c_str();
                    break;
                case BaseValue::Category::NUMBER:
                    switch (static_cast<Number*>(value.get())->getTag()) {
                        case Number::Tag::U_LONG: // json only handles long longs.
                        case Number::Tag::LONG:
                            object[((std::string)iterator->first).c_str()] = (static_cast<Number *>(value.get()))->longLongValue();
                            break;
                        case Number::Tag::DOUBLE:
                            object[((std::string)iterator->first).c_str()] = (static_cast<Number *>(value.get()))->doubleValue();
                            break;
                    }
                    break;
                case BaseValue::Category::BOOLEAN:
                    object[((std::string)iterator->first).c_str()] = (static_cast<Boolean*>(value.get()))->getValue();
            }
        }
        return std::make_shared<NRJSON::JsonObject>(object);
    }
}
