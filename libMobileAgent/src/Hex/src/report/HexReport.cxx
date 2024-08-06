//
// Created by Bryce Buchanan on 7/19/17.
//  Copyright © 2023 New Relic. All rights reserved.
//


#include "HexReport.hpp"
#include "AgentData.hpp"
#include <Utilities/BaseValue.hpp>
#include <Utilities/String.hpp>
#include <Utilities/Boolean.hpp>
#include <Utilities/Number.hpp>
#include <Utilities/libLogger.hpp>

using namespace NewRelic::Hex::Report;

HexReport::HexReport(std::shared_ptr<HandledException> exception,
                     const std::shared_ptr<AppInfo>& applicationInfo,
                     const NewRelic::AttributeValidator& attributeValidator) :
        _exception(std::move(exception)),
        _booleanAttributes(std::make_shared<BooleanAttributes>()),
        _stringAttributes(std::make_shared<StringAttributes>()),
        _longAttributes(std::make_shared<LongAttributes>()),
        _doubleAttributes(std::make_shared<DoubleAttributes>()),
        _applicationInfo(applicationInfo),
        _attributeValidator(attributeValidator) {}

void HexReport::setAttributes(std::map<std::string, std::shared_ptr<AttributeBase>> attributes) {
    for (auto it = attributes.begin(); it != attributes.end(); it++) {
        auto key = it->first;
        auto val = it->second;
        auto value = val->getValue();

        if (value != nullptr) {
            switch (value->getCategory()) {
                case NewRelic::BaseValue::Category::STRING:
                    _stringAttributes->add(key,
                                           dynamic_cast<NewRelic::String*>(val->getValue().get())->getValue());
                    break;
                case NewRelic::BaseValue::Category::BOOLEAN:
                    _booleanAttributes->add(key,
                                            dynamic_cast<NewRelic::Boolean*>(val->getValue().get())->getValue());
                    break;
                case NewRelic::BaseValue::Category::NUMBER:
                    switch (dynamic_cast<NewRelic::Number*>(val->getValue().get())->getTag()) {
                        case NewRelic::Number::Tag::DOUBLE:
                            _doubleAttributes->add(key,
                                                   dynamic_cast<NewRelic::Number*>(val->getValue().get())->doubleValue());
                            break;
                        case NewRelic::Number::Tag::LONG:
                        case NewRelic::Number::Tag::U_LONG: //Flat buffer schema doesn't support un-signed longs
                            _longAttributes->add(key,
                                                 dynamic_cast<NewRelic::Number*>(val->getValue().get())->longLongValue());
                            break;
                    }
                    break;
            }
        }
    }
}

// New Event System

void HexReport::setAttributeNoValidation(const char* key,
                             long long value) {
    try {
        //if (_attributeValidator.getNameValidator()(key)) {
            _longAttributes->add(std::string(key), value);
       // }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%d': %s", key, value,
                   e.what());
    }
}

void HexReport::setAttributeNoValidation(const char* key,
                                         double value) {
    try {
      //  if (_attributeValidator.getNameValidator()(key)) {
            _doubleAttributes->add(std::string(key), value);
      //  }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%f': %s", key, value,
                   e.what());
    }
}
void HexReport::setAttributeNoValidation(const char* key,
                             const char* value) {
    try {
       // if (_attributeValidator.getNameValidator()(key) &&
       //     _attributeValidator.getValueValidator()(value)) {
            _stringAttributes->add(std::string(key), std::string(value));
       // }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%s': %s", key, value,
                   e.what());
    }
}

void HexReport::setAttributeNoValidation(const char* key,
                             bool value) {
    try {
       // if (_attributeValidator.getNameValidator()(key)) {
            _booleanAttributes->add(std::string(key), value);
       // }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%s': %s", key,
                   value ? "true" : "false", e.what());
    }
}

// Old Event System
void HexReport::setAttribute(const char* key,
                             long long value) {
    try {
        if (_attributeValidator.getNameValidator()(key)) {
            _longAttributes->add(std::string(key), value);
        }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%d': %s", key, value,
                   e.what());
    }
}
void HexReport::setAttribute(const char* key,
                             double value) {
    try {
        if (_attributeValidator.getNameValidator()(key)) {
            _doubleAttributes->add(std::string(key), value);
        }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%f': %s", key, value,
                   e.what());
    }
}

void HexReport::setAttribute(const char* key,
                             const char* value) {
    try {
        if (_attributeValidator.getNameValidator()(key) &&
            _attributeValidator.getValueValidator()(value)) {
            _stringAttributes->add(std::string(key), std::string(value));
        }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%s': %s", key, value,
                   e.what());
    }
}

void HexReport::setAttribute(const char* key,
                             bool value) {
    try {
        if (_attributeValidator.getNameValidator()(key)) {
            _booleanAttributes->add(std::string(key), value);
        }
    } catch (std::exception& e) {
        LLOG_ERROR("Handled Exception: Failed to insert attribute key, '%s', and value, '%s': %s", key,
                   value ? "true" : "false", e.what());
    }
}

flatbuffers::Offset<com::newrelic::mobile::fbs::HexAgentData>
HexReport::finalize(flatbuffers::FlatBufferBuilder& builder) const {
    if (_exception == nullptr) throw std::invalid_argument("Handled Exception not present.");
    if (_applicationInfo == nullptr) throw std::invalid_argument("application information no present.");
    auto agentData = std::make_shared<Report::AgentData>(_stringAttributes,
                                                         _booleanAttributes,
                                                         _doubleAttributes,
                                                         _longAttributes,
                                                         _applicationInfo,
                                                         _exception);

    return agentData->serialize(builder);
}

const std::shared_ptr<BooleanAttributes>& HexReport::getBooleanAttributes() const {
    return _booleanAttributes;
}

const std::shared_ptr<StringAttributes>& HexReport::getStringAttributes() const {
    return _stringAttributes;
}

const std::shared_ptr<LongAttributes>& HexReport::getLongAttributes() const {
    return _longAttributes;
}

const std::shared_ptr<DoubleAttributes>& HexReport::getDoubleAttributes() const {
    return _doubleAttributes;
}

